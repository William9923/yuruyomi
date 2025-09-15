use crate::get_build_info;
use axum::{
    routing::{get, post},
    Json, Router,
};
use serde::Deserialize;
use shared::usecases::{check_update, install_update};

use crate::state::State as AppState;
use crate::AppError;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/update/check", get(check_for_updates))
        .route("/update/install", post(install_update_handler))
}

async fn check_for_updates() -> Result<Json<check_update::CheckUpdateResponse>, crate::AppError> {
    let build_info = get_build_info()
        .ok_or_else(|| AppError::Other(anyhow::anyhow!("Could not get build info. In development, make sure BUILD_INFO.json exists next to the server executable, or use a release build.")))?;

    // Skip update check for development builds
    if build_info.version.contains("-dev") {
        return Ok(Json(check_update::CheckUpdateResponse {
            available: false,
            current_version: build_info.version.clone(),
            latest_version: build_info.version.clone(),
            release_url: "https://github.com/William9923/yuruyomi/releases".to_string(),
            auto_installable: false,
        }));
    }

    let response = check_update::check_update(build_info.version).await?;
    Ok(Json(response))
}

#[derive(Deserialize)]
struct InstallUpdateRequest {
    version: String,
}

#[axum_macros::debug_handler]
async fn install_update_handler(
    Json(request): Json<InstallUpdateRequest>,
) -> Result<Json<()>, crate::AppError> {
    let build_info = get_build_info().ok_or_else(|| {
        AppError::Other(anyhow::anyhow!(
            "Could not get build info. Updates are not supported in development builds."
        ))
    })?;

    // Prevent updates for development builds
    if build_info.version.contains("-dev") || build_info.build == "development" {
        return Err(AppError::Other(anyhow::anyhow!(
            "Updates are not supported in development builds. Please use a release build for update functionality."
        )));
    }

    install_update::install_update(request.version, build_info.build).await?;
    Ok(Json(()))
}
