use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Request, Response, Server};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let ports_s: String = std::env::var("PORT").unwrap_or("8080".to_string());
    let ports = ports_s.split(",");

    let service = make_service_fn(|_| async {
        Ok::<_, hyper::Error>(service_fn(|_req: Request<Body>| async {
            Ok::<Response<Body>, hyper::Error>(Response::new(Body::from(HELLO_WORLD)))
        }))
    });

    let mut v = Vec::new();
    for port in ports {
        let addr: std::net::SocketAddr = ("[::]:".to_owned() + port).parse()?;
        println!("Listening on http://{}", addr);
        let server = Server::bind(&addr).serve(service);
        v.push(server);
    }
    futures::future::join_all(v).await;

    Ok(())
}

static HELLO_WORLD: &'static [u8] = b"Hello, world!";
