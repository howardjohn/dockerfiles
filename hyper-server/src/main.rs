use futures::TryFutureExt;
use std::error::Error;
use std::ops::Add;
use std::sync::atomic::{AtomicU64, Ordering};
use std::{convert::Infallible, sync::Mutex};
use std::{sync::Arc, time::Instant};

use futures::FutureExt;
use hyper::server::conn::AddrStream;
use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Request, Response, Server};
use tokio::io;
use tokio::io::AsyncWriteExt;
use tracing::{info, trace, warn};
use tracing_subscriber::FmtSubscriber;

static REQUESTS: AtomicU64 = AtomicU64::new(0);

async fn hello_world(_req: Request<Body>) -> Result<Response<Body>, Infallible> {
    Ok(Response::new(Body::from(HELLO_WORLD)))
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error + Send + Sync>> {
    // a builder for `FmtSubscriber`.
    let subscriber = FmtSubscriber::builder()
        // all spans/events with a level higher than TRACE (e.g, debug, info, warn, etc.)
        // will be written to stdout.
        .with_max_level(tracing::Level::INFO)
        // completes the builder.
        .finish();
    tracing::subscriber::set_global_default(subscriber).expect("setting default subscriber failed");
    let proxy_type: String = std::env::var("PROXY_TYPE").unwrap_or("DIRECT".to_string());
    let ports_s: String = std::env::var("PORT").unwrap_or("8080".to_string());
    let ports = ports_s.split(",");
    info!("Starting proxy type {} on ports {}", proxy_type, ports_s);

    match proxy_type.as_str() {
        "HTTP" => {
            let mut v = Vec::new();
            for port in ports {
                let addr: std::net::SocketAddr = ("[::]:".to_owned() + port).parse()?;
                info!("Listening on http://{}", addr);
                let first_request_time: Arc<Mutex<Instant>> = Arc::new(Mutex::new(Instant::now()));
                let client = Arc::new(hyper::Client::new());

                let proxy_service = make_service_fn(move |socket: &AddrStream| {
                    let orig = orig_dst_addr_stream(socket).unwrap_or(socket.remote_addr());
                    let client = client.clone();
                    info!(
                        "connection established with original destination {:?}",
                        orig
                    );
                    let frt = first_request_time.clone();
                    async move {
                        Ok::<_, Infallible>(service_fn(move |mut req: Request<Body>| {
                            let client = client.clone();
                            let frt = frt.clone();
                            // TODO: use original IP, but this would require local bind to 127.0.0.6
                            *req.uri_mut() = ("http://127.0.0.1:".to_owned()
                                + &orig.port().to_string()
                                + &req.uri().path().to_string())
                                .parse()
                                .unwrap();
                            // let request = Request::builder()
                            //     .method(req.method())
                            //     .version(req.version())
                            //     .uri("http://".to_owned() + &orig.to_string() + &req.uri().to_string())
                            //     .headers_mut().
                            //     .body(req.body())
                            //     .unwrap();
                            trace!("request: {:#?}", req);
                            async move {
                                let resp = client.request(req).await;
                                trace!("response: {:#?}", resp);
                                let rc = REQUESTS.fetch_add(1, Ordering::Relaxed);
                                if rc == 0 {
                                    let mut frt2 = frt.lock().unwrap();
                                    *frt2 = Instant::now();
                                    info!("Completed first request");
                                } else if rc % 10000 == 0 {
                                    info!(
                                        "Completed request {}, rate is {:?}",
                                        rc,
                                        rc as f64 / frt.lock().unwrap().elapsed().as_secs_f64()
                                    );
                                }
                                resp
                            }
                        }))
                    }
                });
                let server = Server::bind(&addr).serve(proxy_service);
                v.push(server);
            }
            futures::future::join_all(v).await;
        }
        "TCP" => {
            let mut v = Vec::new();
            for port in ports {
                let first_request_time: Arc<Mutex<Instant>> = Arc::new(Mutex::new(Instant::now()));
                let proxy = async move {
                    let addr: std::net::SocketAddr = ("[::]:".to_owned() + port).parse().unwrap();
                    info!("Listening on http://{}", addr);
                    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
                    while let Ok((inbound, socket)) = listener.accept().await {
                        let mut orig = orig_dst_addr(&inbound).unwrap_or(inbound.peer_addr().unwrap());
                        // TODO: use original IP, but this would require local bind to 127.0.0.6
                        orig.set_ip("127.0.0.1".parse().unwrap());
                        let transfer = transfer(inbound, orig).map(|r| {
                            if let Err(e) = r {
                                warn!("Failed to transfer; error={}", e);
                            }
                        });

                        tokio::spawn(transfer);
                    }
                };
                v.push(proxy);
            }
            futures::future::join_all(v).await;
        }
        "DIRECT" => {
            let mut v = Vec::new();
            for port in ports {
                let addr: std::net::SocketAddr = ("[::]:".to_owned() + port).parse()?;
                println!("Listening on http://{}", addr);
                let first_request_time: Arc<Mutex<Instant>> = Arc::new(Mutex::new(Instant::now()));
                let direct_service = make_service_fn(move |socket: &AddrStream| {
                    let frt = first_request_time.clone();
                    async move {
                        Ok::<_, Infallible>(service_fn(move |_req: Request<Body>| {
                            let rc = REQUESTS.fetch_add(1, Ordering::Relaxed);
                            if rc == 0 {
                                let mut frt2 = frt.lock().unwrap();
                                *frt2 = Instant::now();
                                println!("Completed first request");
                            } else if rc % 10000 == 0 {
                                println!(
                                    "Completed request {}, rate is {:?}",
                                    rc,
                                    rc as f64 / frt.lock().unwrap().elapsed().as_secs_f64()
                                );
                            }
                            hello_world(_req)
                        }))
                    }
                });
                let server = Server::bind(&addr).serve(direct_service);
                v.push(server);
            }
            futures::future::join_all(v).await;
        }
        _ => {
            panic!("invalid proxy_type {}", proxy_type);
        }
    }

    Ok(())
}

static HELLO_WORLD: &'static [u8] = b"";

#[cfg(target_os = "linux")]
#[allow(unsafe_code)]
fn orig_dst_addr(sock: &tokio::net::TcpStream) -> tokio::io::Result<std::net::SocketAddr> {
    use std::os::unix::io::AsRawFd;
    let fd = sock.as_raw_fd();
    unsafe { linux::so_original_dst(fd) }
}

#[cfg(target_os = "linux")]
#[allow(unsafe_code)]
fn orig_dst_addr2<T: std::os::unix::io::AsRawFd>(
    sock: T,
) -> tokio::io::Result<std::net::SocketAddr> {
    use std::os::unix::io::AsRawFd;
    let fd = sock.as_raw_fd();
    unsafe { linux::so_original_dst(fd) }
}

#[cfg(not(target_os = "linux"))]
fn orig_dst_addr2<T: std::os::unix::io::AsRawFd>(_: T) -> tokio::io::Result<std::net::SocketAddr> {
    Err(io::Error::new(
        io::ErrorKind::Other,
        "SO_ORIGINAL_DST not supported on this operating system",
    ))
}

fn orig_dst_addr_stream(sock: &AddrStream) -> tokio::io::Result<std::net::SocketAddr> {
    use std::os::unix::io::AsRawFd;
    let fd = sock.as_raw_fd();
    unsafe { linux::so_original_dst(fd) }
}

#[cfg(not(target_os = "linux"))]
fn orig_dst_addr(_: &TcpStream) -> io::Result<SocketAddr> {
    Err(io::Error::new(
        io::ErrorKind::Other,
        "SO_ORIGINAL_DST not supported on this operating system",
    ))
}

#[cfg(not(target_os = "linux"))]
fn orig_dst_addr_stream(_: AddrStream) -> io::Result<SocketAddr> {
    Err(io::Error::new(
        io::ErrorKind::Other,
        "SO_ORIGINAL_DST not supported on this operating system",
    ))
}

#[cfg(target_os = "linux")]
#[allow(unsafe_code)]
mod linux {
    use std::net::{Ipv4Addr, Ipv6Addr, SocketAddr, SocketAddrV4, SocketAddrV6};
    use std::os::unix::io::RawFd;
    use std::{io, mem};

    use log::warn;

    pub unsafe fn so_original_dst(fd: RawFd) -> io::Result<SocketAddr> {
        let mut sockaddr: libc::sockaddr_storage = mem::zeroed();
        let mut socklen: libc::socklen_t = mem::size_of::<libc::sockaddr_storage>() as u32;
        let ret = libc::getsockopt(
            fd,
            libc::SOL_IP,
            libc::SO_ORIGINAL_DST,
            &mut sockaddr as *mut _ as *mut _,
            &mut socklen as *mut _ as *mut _,
        );
        if ret != 0 {
            let e = io::Error::last_os_error();
            warn!("failed to read SO_ORIGINAL_DST: {:?}", e);
            return Err(e);
        }
        mk_addr(&sockaddr, socklen)
    }

    // Borrowed with love from net2-rs
    // https://github.com/rust-lang-nursery/net2-rs/blob/1b4cb4fb05fbad750b271f38221eab583b666e5e/src/socket.rs#L103
    //
    // Copyright (c) 2014 The Rust Project Developers
    fn mk_addr(storage: &libc::sockaddr_storage, len: libc::socklen_t) -> io::Result<SocketAddr> {
        match storage.ss_family as libc::c_int {
            libc::AF_INET => {
                assert!(len as usize >= mem::size_of::<libc::sockaddr_in>());
                let sa = {
                    let sa = storage as *const _ as *const libc::sockaddr_in;
                    unsafe { *sa }
                };
                let bits = ntoh32(sa.sin_addr.s_addr);
                let ip = Ipv4Addr::new(
                    (bits >> 24) as u8,
                    (bits >> 16) as u8,
                    (bits >> 8) as u8,
                    bits as u8,
                );
                let port = sa.sin_port;
                Ok(SocketAddr::V4(SocketAddrV4::new(ip, ntoh16(port))))
            }
            libc::AF_INET6 => {
                assert!(len as usize >= mem::size_of::<libc::sockaddr_in6>());
                let sa = {
                    let sa = storage as *const _ as *const libc::sockaddr_in6;
                    unsafe { *sa }
                };
                let arr = sa.sin6_addr.s6_addr;
                let ip = Ipv6Addr::new(
                    (arr[0] as u16) << 8 | (arr[1] as u16),
                    (arr[2] as u16) << 8 | (arr[3] as u16),
                    (arr[4] as u16) << 8 | (arr[5] as u16),
                    (arr[6] as u16) << 8 | (arr[7] as u16),
                    (arr[8] as u16) << 8 | (arr[9] as u16),
                    (arr[10] as u16) << 8 | (arr[11] as u16),
                    (arr[12] as u16) << 8 | (arr[13] as u16),
                    (arr[14] as u16) << 8 | (arr[15] as u16),
                );
                let port = sa.sin6_port;
                let flowinfo = sa.sin6_flowinfo;
                let scope_id = sa.sin6_scope_id;
                Ok(SocketAddr::V6(SocketAddrV6::new(
                    ip,
                    ntoh16(port),
                    flowinfo,
                    scope_id,
                )))
            }
            _ => Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "invalid argument",
            )),
        }
    }

    fn ntoh16(i: u16) -> u16 {
        <u16>::from_be(i)
    }

    fn ntoh32(i: u32) -> u32 {
        <u32>::from_be(i)
    }
}

async fn transfer(
    mut inbound: tokio::net::TcpStream,
    proxy_addr: std::net::SocketAddr,
) -> Result<(), Box<dyn Error>> {
    let mut outbound = tokio::net::TcpStream::connect(proxy_addr).await?;

    let (mut ri, mut wi) = inbound.split();
    let (mut ro, mut wo) = outbound.split();

    let client_to_server = async {
        io::copy(&mut ri, &mut wo).await?;
        wo.shutdown().await
    };

    let server_to_client = async {
        io::copy(&mut ro, &mut wi).await?;
        wi.shutdown().await
    };

    tokio::try_join!(client_to_server, server_to_client)?;

    Ok(())
}
