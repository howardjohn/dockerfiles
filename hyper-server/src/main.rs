use futures::FutureExt;
use http_body_util::Empty;
use hyper::body::{Body, Bytes, Incoming};
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Request, Response};
use ppp::v2::Addresses;
use std::error::Error;
use std::future::Future;
use std::net::{SocketAddr, SocketAddrV4};
use std::pin::Pin;
use std::sync::atomic::{AtomicU64, Ordering};
use std::task::{Context, Poll, ready};
use std::{convert::Infallible, sync::Mutex};
use std::{sync::Arc, time::Instant};
use tokio::io;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tracing::{info, warn};
use tracing_subscriber::FmtSubscriber;

static REQUESTS: AtomicU64 = AtomicU64::new(0);

struct Drain(Incoming);

impl Future for Drain {
    type Output = ();

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        loop {
            let this = &mut self.0;
            let frame = ready!(Pin::new(this).poll_frame(cx));

            match frame {
                None | Some(Err(_)) => {
                    return Poll::Ready(());
                }
                _ => {}
            };
        }
    }
}

async fn hello_world(
    req: Request<hyper::body::Incoming>,
) -> Result<Response<Empty<Bytes>>, Infallible> {
    let body = req.into_body();
    if !body.is_end_stream() {
        tokio::task::spawn(Drain(body));
    }
    Ok(Response::new(Empty::new()))
}

#[derive(Copy, Clone)]
enum ProxyTarget {
    OrigDst,
    Proxy(Option<SocketAddr>),
    Explicit(SocketAddr),
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
    let proxy_target = match std::env::var("PROXY_TARGET").as_deref() {
        Ok("PROXY") => ProxyTarget::Proxy(None),
        Ok("ORIG_DST") => ProxyTarget::OrigDst,
        Ok(v) if v.starts_with("PROXY/") => {
            ProxyTarget::Proxy(Some(v.strip_prefix("PROXY/").unwrap().parse()?))
        }
        Ok(v) => ProxyTarget::Explicit(v.parse()?),
        Err(_) => ProxyTarget::OrigDst,
    };
    let ports_s: String = std::env::var("PORT").unwrap_or("8080".to_string());
    let ports = ports_s.split(',');
    info!("Starting proxy type {} on ports {}", proxy_type, ports_s);

    let mut v = Vec::new();
    for port in ports {
        let first_request_time: Arc<Mutex<Instant>> = Arc::new(Mutex::new(Instant::now()));
        let proxy_type = proxy_type.clone();
        let proxy = async move {
            let addr: std::net::SocketAddr = ("[::]:".to_owned() + port).parse().unwrap();
            info!("Listening on http://{}", addr);
            let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
            while let Ok((mut inbound, _socket)) = listener.accept().await {
                inbound.set_nodelay(true).unwrap();
                let frt = first_request_time.clone();
                let target = orig_dst_addr(proxy_target, &mut inbound)
                    .await
                    .unwrap_or(inbound.peer_addr().unwrap());
                // TODO: use original IP, but this would require local bind to 127.0.0.6
                // orig.set_ip("127.0.0.1".parse().unwrap());
                match proxy_type.as_str() {
                    "HTTP" => {
                        let outbound = tokio::net::TcpStream::connect(target).await.unwrap();
                        outbound.set_nodelay(true).unwrap();
                        let req = Request::builder()
                            .uri(format!("http://{target}"))
                            .header(hyper::header::HOST, target.to_string())
                            .body(Empty::<Bytes>::new())
                            .unwrap();
                        let io = hyper_util::rt::TokioIo::new(outbound);
                        let (sender, conn) =
                            hyper::client::conn::http1::handshake(io).await.unwrap();
                        tokio::task::spawn(async move {
                            if let Err(err) = conn.await {
                                eprintln!("Connection failed: {err:?}");
                            }
                        });
                        let sender = Arc::new(tokio::sync::Mutex::new(sender));
                        let proxy = http1::Builder::new()
                            .serve_connection(
                                hyper_util::rt::TokioIo::new(inbound),
                                service_fn(move |_req| {
                                    let sender = sender.clone();
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
                                    let req = req.clone();
                                    async move {
                                        let mut sender = sender.lock().await;
                                        let _resp = sender.send_request(req).await.unwrap();
                                        // let body = http_body_util::BodyStream::new(resp.body());
                                        // let resp_body = http_body_util::StreamBody::new(body);
                                        // Ok::<Response<_>, Infallible>(Response::new(resp_body))
                                        Ok::<Response<_>, Infallible>(Response::new(
                                            Empty::<Bytes>::new(),
                                        ))
                                    }
                                }),
                            )
                            .map(|r| {
                                if let Err(e) = r {
                                    warn!("Failed to transfer; error={}", e);
                                } else {
                                    info!("Connection complete without error");
                                }
                            });
                        tokio::spawn(proxy);
                    }
                    "TCP" => {
                        let transfer = transfer(inbound, target).map(|r| {
                            if let Err(e) = r {
                                warn!("Failed to transfer; error={}", e);
                            }
                        });

                        tokio::spawn(transfer);
                    }
                    "DIRECT" => {
                        tokio::spawn(async move {
                            let builder = hyper_util::server::conn::auto::Builder::new(
                                ::hyper_util::rt::TokioExecutor::new(),
                            );
                            builder
                                .serve_connection(
                                    hyper_util::rt::TokioIo::new(inbound),
                                    service_fn(move |_req| {
                                        let rc = REQUESTS.fetch_add(1, Ordering::Relaxed);
                                        if rc == 0 {
                                            let mut frt2 = frt.lock().unwrap();
                                            *frt2 = Instant::now();
                                            println!("Completed first request");
                                        } else if rc % 10000 == 0 {
                                            println!(
                                                "Completed request {}, rate is {:?}",
                                                rc,
                                                rc as f64
                                                    / frt.lock().unwrap().elapsed().as_secs_f64()
                                            );
                                        }
                                        hello_world(_req)
                                    }),
                                )
                                .map(|r| {
                                    if let Err(e) = r {
                                        warn!("Failed to transfer; error={}", e);
                                    }
                                })
                                .await
                        });
                    }
                    _ => {
                        panic!("invalid proxy_type {proxy_type}");
                    }
                }
            }
        };
        v.push(proxy);
    }
    futures::future::join_all(v).await;
    Ok(())
}

#[cfg(target_os = "linux")]
#[allow(unsafe_code)]
async fn orig_dst_addr(
    mode: ProxyTarget,
    sock: &mut tokio::net::TcpStream,
) -> tokio::io::Result<std::net::SocketAddr> {
    use std::os::unix::io::AsRawFd;
    match mode {
        ProxyTarget::Proxy(dst) => {
            let mut buffer = [0; 512];
            let read = sock.peek(&mut buffer).await?;
            let header = ppp::HeaderResult::parse(&buffer[..read]);
            let ppp::HeaderResult::V2(Ok(header)) = header else {
                panic!("did not parse proxy protocol");
            };
            let Addresses::IPv4(addresses) = header.addresses else {
                panic!("no ipv4 addresses in proxy protocol");
            };
            let addr = SocketAddrV4::new(addresses.destination_address, addresses.destination_port);
            let mut drain = vec![0; read];
            sock.read_exact(&mut drain).await?;
            Ok(dst.unwrap_or(addr.into()))
        }
        ProxyTarget::OrigDst => {
            let fd = sock.as_raw_fd();
            unsafe { linux::so_original_dst(fd) }
        }
        ProxyTarget::Explicit(dst) => Ok(dst),
    }
}

#[cfg(not(target_os = "linux"))]
fn orig_dst_addr(_: &TcpStream) -> io::Result<SocketAddr> {
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
        unsafe {
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
                warn!("failed to read SO_ORIGINAL_DST: {e:?}");
                return Err(e);
            }
            mk_addr(&sockaddr, socklen)
        }
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
    outbound.set_nodelay(true)?;

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
