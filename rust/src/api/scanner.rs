use crate::api::models::SafeCardModel;
use crate::engine::emv::EmvEngine;
use flutter_rust_bridge::DartFnFuture;

pub async fn scan_emv_card(
    transceiver: impl Fn(Vec<u8>) -> DartFnFuture<Vec<u8>>,
) -> Result<SafeCardModel, String> {
    let engine = EmvEngine::new(transceiver);
    engine.execute_session().await
}
