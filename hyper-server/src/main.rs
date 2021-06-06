use std::{convert::Infallible, sync::Mutex};

use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Request, Response, Server};
use std::sync::atomic::{AtomicU64, Ordering};
use std::{sync::Arc, time::Instant};

static REQUESTS: AtomicU64 = AtomicU64::new(0);

async fn hello_world(_req: Request<Body>) -> Result<Response<Body>, Infallible> {
    Ok(Response::new(Body::from(HELLO_WORLD)))
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let ports_s: String = std::env::var("PORT").unwrap_or("8080".to_string());
    let ports = ports_s.split(",");

    let mut v = Vec::new();
    for port in ports {
        let addr: std::net::SocketAddr = ("[::]:".to_owned() + port).parse()?;
        println!("Listening on http://{}", addr);
        let first_request_time: Arc<Mutex<Instant>> = Arc::new(Mutex::new(Instant::now()));
        let service = make_service_fn(move |_| {
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
        let server = Server::bind(&addr).serve(service);
        v.push(server);
    }
    futures::future::join_all(v).await;

    Ok(())
}

static HELLO_WORLD: &'static [u8] = b"Hello, world!";
