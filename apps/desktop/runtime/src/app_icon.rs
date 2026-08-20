#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AppIconImage {
    pub pixels: Vec<u8>,
    pub width: u32,
    pub height: u32,
}

#[derive(Debug, Clone, Copy)]
struct IconPalette {
    top: [f32; 3],
    bottom: [f32; 3],
}

pub const ICON_SIZE: u32 = 128;
const MACOS_ICON_CONTENT_INSET_RATIO: f32 = 0.09;
const WINDOWS_ICON_CONTENT_INSET_RATIO: f32 = 0.0;
/// Matches `rx="40"` on the 128×128 settings SVGs.
const ICON_CORNER_RATIO: f32 = 40.0 / 128.0;

pub fn render_app_icon(style: &str, size: u32) -> AppIconImage {
    load_bundled_app_icon(style, size, MACOS_ICON_CONTENT_INSET_RATIO)
        .unwrap_or_else(|| render_app_icon_with_inset(style, size, MACOS_ICON_CONTENT_INSET_RATIO))
}

pub fn render_windows_app_icon(style: &str, size: u32) -> AppIconImage {
    load_bundled_app_icon(style, size, WINDOWS_ICON_CONTENT_INSET_RATIO).unwrap_or_else(|| {
        render_app_icon_with_inset(style, size, WINDOWS_ICON_CONTENT_INSET_RATIO)
    })
}

fn load_bundled_app_icon(style: &str, size: u32, inset_ratio: f32) -> Option<AppIconImage> {
    let path = crate::runtime_bridge::runtime_assets_path()
        .join("icons")
        .join("icon.png");
    let mut source = image::open(&path).ok()?.into_rgba8();
    apply_icon_style_tint(&mut source, style);
    apply_icon_corner_mask(&mut source);
    Some(fit_icon_into_canvas(&source, size, inset_ratio))
}

struct IconStyleTint {
    plate: [f32; 3],
    mark_top: [f32; 3],
    mark_bottom: [f32; 3],
}

fn rgb8(hex: u32) -> [f32; 3] {
    [
        ((hex >> 16) & 0xFF) as f32 / 255.0,
        ((hex >> 8) & 0xFF) as f32 / 255.0,
        (hex & 0xFF) as f32 / 255.0,
    ]
}

fn icon_style_tint(style: &str) -> Option<IconStyleTint> {
    match style {
        "cobalt" => Some(IconStyleTint {
            plate: rgb8(0x12151C),
            mark_top: rgb8(0xB7C6DB),
            mark_bottom: rgb8(0x5B6C86),
        }),
        "sunset" => Some(IconStyleTint {
            plate: rgb8(0x140A08),
            mark_top: rgb8(0xFFB089),
            mark_bottom: rgb8(0xE23A2E),
        }),
        "forest" => Some(IconStyleTint {
            plate: rgb8(0x07140F),
            mark_top: rgb8(0x7DFFC3),
            mark_bottom: rgb8(0x1F9A64),
        }),
        _ => None,
    }
}

fn apply_icon_style_tint(image: &mut image::RgbaImage, style: &str) {
    let Some(tint) = icon_style_tint(style) else {
        return;
    };
    let width = image.width().max(1);
    let height = image.height().max(1) as f32;
    for (index, pixel) in image.pixels_mut().enumerate() {
        let alpha = pixel[3];
        if alpha < 8 {
            continue;
        }
        let r = pixel[0] as f32 / 255.0;
        let g = pixel[1] as f32 / 255.0;
        let b = pixel[2] as f32 / 255.0;
        let max = r.max(g).max(b);
        let min = r.min(g).min(b);
        let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        let sat = if max > 1e-4 { (max - min) / max } else { 0.0 };
        if lum > 0.78 && sat < 0.20 {
            continue;
        }
        if lum < 0.22 && sat < 0.35 {
            pixel[0] = to_u8(tint.plate[0]);
            pixel[1] = to_u8(tint.plate[1]);
            pixel[2] = to_u8(tint.plate[2]);
            continue;
        }
        let row = (index as u32 / width) as f32;
        let t = (row + 0.5) / height;
        let rgb = mix_rgb(tint.mark_top, tint.mark_bottom, t);
        pixel[0] = to_u8(rgb[0]);
        pixel[1] = to_u8(rgb[1]);
        pixel[2] = to_u8(rgb[2]);
    }
}

fn apply_icon_corner_mask(image: &mut image::RgbaImage) {
    let width = image.width().max(1);
    let height = image.height().max(1);
    let size_x = width as f32;
    let size_y = height as f32;
    let radius = size_x.min(size_y) * ICON_CORNER_RATIO;
    for (index, pixel) in image.pixels_mut().enumerate() {
        if pixel[3] == 0 {
            continue;
        }
        let x = (index as u32 % width) as f32 + 0.5;
        let y = (index as u32 / width) as f32 + 0.5;
        let distance = rounded_rect_distance(x, y, 0.0, 0.0, size_x, size_y, radius);
        let coverage = smoothstep(1.0, -1.0, distance);
        pixel[3] = to_u8(pixel[3] as f32 / 255.0 * coverage);
    }
}

fn fit_icon_into_canvas(source: &image::RgbaImage, size: u32, inset_ratio: f32) -> AppIconImage {
    let inset = (size as f32 * inset_ratio).round().max(0.0) as u32;
    let content = size.saturating_sub(inset.saturating_mul(2)).max(1);
    let resized = image::imageops::resize(
        source,
        content,
        content,
        image::imageops::FilterType::Lanczos3,
    );
    let mut canvas = image::RgbaImage::new(size, size);
    image::imageops::replace(&mut canvas, &resized, inset as i64, inset as i64);
    AppIconImage {
        pixels: canvas.into_raw(),
        width: size,
        height: size,
    }
}

fn render_app_icon_with_inset(style: &str, size: u32, inset_ratio: f32) -> AppIconImage {
    let palette = icon_palette(style);
    let mut pixels = vec![0_u8; (size * size * 4) as usize];
    for y in 0..size {
        for x in 0..size {
            let color = icon_pixel(
                x as f32 + 0.5,
                y as f32 + 0.5,
                size as f32,
                palette,
                inset_ratio,
            );
            let offset = ((y * size + x) * 4) as usize;
            pixels[offset] = to_u8(color[0]);
            pixels[offset + 1] = to_u8(color[1]);
            pixels[offset + 2] = to_u8(color[2]);
            pixels[offset + 3] = to_u8(color[3]);
        }
    }
    AppIconImage {
        pixels,
        width: size,
        height: size,
    }
}

pub fn apply_app_icon(style: &str) -> Result<(), String> {
    apply_app_icon_impl(style)
}

#[cfg(target_os = "macos")]
fn apply_app_icon_impl(style: &str) -> Result<(), String> {
    use dispatch2::DispatchQueue;
    use image::{ExtendedColorType, ImageEncoder, codecs::png::PngEncoder};
    use objc2::{AnyThread, MainThreadMarker};
    use objc2_app_kit::{NSApplication, NSImage};
    use objc2_foundation::NSData;
    use std::io::Cursor;
    use std::sync::Mutex;

    fn run_on_main<F, R>(f: F) -> R
    where
        F: FnOnce(MainThreadMarker) -> R + Send + 'static,
        R: Send + 'static,
    {
        if let Some(marker) = MainThreadMarker::new() {
            return f(marker);
        }

        let result = Mutex::new(None);
        DispatchQueue::main().exec_sync(|| {
            let marker = unsafe { MainThreadMarker::new_unchecked() };
            *result.lock().expect("icon main-thread result poisoned") = Some(f(marker));
        });
        result
            .into_inner()
            .expect("icon main-thread result poisoned")
            .expect("main dispatch did not run")
    }

    let image = render_app_icon(style, 512);
    let mut png = Vec::new();
    PngEncoder::new(Cursor::new(&mut png))
        .write_image(
            &image.pixels,
            image.width,
            image.height,
            ExtendedColorType::Rgba8,
        )
        .map_err(|error| error.to_string())?;

    run_on_main(move |marker| {
        let data = NSData::with_bytes(&png);
        let ns_image = NSImage::initWithData(NSImage::alloc(), &data)
            .ok_or_else(|| "failed to create application icon image".to_string())?;
        let app = NSApplication::sharedApplication(marker);
        unsafe { app.setApplicationIconImage(Some(&ns_image)) };
        Ok(())
    })
}

#[cfg(not(target_os = "macos"))]
fn apply_app_icon_impl(_style: &str) -> Result<(), String> {
    Ok(())
}

fn icon_pixel(x: f32, y: f32, size: f32, palette: IconPalette, inset_ratio: f32) -> [f32; 4] {
    let inset = size * inset_ratio;
    let rect_min = inset;
    let rect_max = size - inset;
    let rect_size = rect_max - rect_min;
    let radius = size * 0.2243;
    let distance = rounded_rect_distance(x, y, rect_min, rect_min, rect_size, rect_size, radius);
    let edge_alpha = smoothstep(1.0, -1.0, distance);
    if edge_alpha <= 0.0 {
        return [0.0, 0.0, 0.0, 0.0];
    }

    let t = ((y - rect_min) / rect_size).clamp(0.0, 1.0);
    let mut rgb = mix_rgb(palette.top, palette.bottom, t);
    let top_center = [size * 0.5, rect_min + size * 0.08];
    let top_glow = (1.0 - distance_to(x, y, top_center) / (size * 0.5)).clamp(0.0, 1.0) * 0.04;
    rgb = mix_rgb(rgb, [1.0, 1.0, 1.0], top_glow);

    let bottom_center = [size * 0.5, rect_max];
    let bottom_shade =
        (1.0 - distance_to(x, y, bottom_center) / (size * 0.45)).clamp(0.0, 1.0) * 0.03;
    rgb = mix_rgb(rgb, [0.0, 0.0, 0.0], bottom_shade);

    let cx = size * 0.5;
    let cy = size * 0.5;
    let chevron_h = size * 0.2804;
    let chevron_w = size * 0.1587;
    let weight = size * 0.0843;
    let back_alpha =
        chevron_alpha(x, y, cx + size * -0.0935, cy, chevron_w, chevron_h, weight) * 0.40;
    rgb = mix_rgb(rgb, [1.0, 1.0, 1.0], back_alpha);

    let front_alpha = chevron_alpha(x, y, cx + size * 0.0935, cy, chevron_w, chevron_h, weight);
    rgb = mix_rgb(rgb, [1.0, 1.0, 1.0], front_alpha);

    let inner_distance = rounded_rect_distance(
        x,
        y,
        rect_min + 0.5,
        rect_min + 0.5,
        rect_size - 1.0,
        rect_size - 1.0,
        radius,
    )
    .abs();
    let border_alpha = (1.0 - inner_distance).clamp(0.0, 1.0) * 0.08;
    rgb = mix_rgb(rgb, [1.0, 1.0, 1.0], border_alpha);
    [rgb[0], rgb[1], rgb[2], edge_alpha]
}

fn icon_palette(style: &str) -> IconPalette {
    match style {
        "cobalt" => IconPalette {
            top: [0.12, 0.14, 0.20],
            bottom: [0.11, 0.13, 0.18],
        },
        "sunset" => IconPalette {
            top: [0.96, 0.42, 0.32],
            bottom: [0.93, 0.38, 0.29],
        },
        "forest" => IconPalette {
            top: [0.18, 0.62, 0.45],
            bottom: [0.16, 0.57, 0.42],
        },
        _ => IconPalette {
            top: [0.24, 0.50, 0.98],
            bottom: [0.22, 0.45, 0.93],
        },
    }
}

fn chevron_alpha(x: f32, y: f32, cx: f32, cy: f32, width: f32, height: f32, stroke: f32) -> f32 {
    let left_top = [cx - width * 0.5, cy - height * 0.5];
    let center = [cx + width * 0.5, cy];
    let left_bottom = [cx - width * 0.5, cy + height * 0.5];
    let distance = distance_to_segment(x, y, left_top, center).min(distance_to_segment(
        x,
        y,
        center,
        left_bottom,
    ));
    smoothstep(stroke * 0.5 + 1.0, stroke * 0.5 - 1.0, distance)
}

fn rounded_rect_distance(x: f32, y: f32, rx: f32, ry: f32, rw: f32, rh: f32, radius: f32) -> f32 {
    let px = (x - (rx + rw * 0.5)).abs() - (rw * 0.5 - radius);
    let py = (y - (ry + rh * 0.5)).abs() - (rh * 0.5 - radius);
    let outside = [px.max(0.0), py.max(0.0)];
    let inside = px.max(py).min(0.0);
    (outside[0] * outside[0] + outside[1] * outside[1]).sqrt() + inside - radius
}

fn distance_to_segment(x: f32, y: f32, a: [f32; 2], b: [f32; 2]) -> f32 {
    let ab = [b[0] - a[0], b[1] - a[1]];
    let ap = [x - a[0], y - a[1]];
    let denom = ab[0] * ab[0] + ab[1] * ab[1];
    if denom <= f32::EPSILON {
        return distance_to(x, y, a);
    }
    let t = ((ap[0] * ab[0] + ap[1] * ab[1]) / denom).clamp(0.0, 1.0);
    distance_to(x, y, [a[0] + ab[0] * t, a[1] + ab[1] * t])
}

fn distance_to(x: f32, y: f32, point: [f32; 2]) -> f32 {
    let dx = x - point[0];
    let dy = y - point[1];
    (dx * dx + dy * dy).sqrt()
}

fn smoothstep(edge0: f32, edge1: f32, value: f32) -> f32 {
    let t = ((value - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

fn mix_rgb(from: [f32; 3], to: [f32; 3], amount: f32) -> [f32; 3] {
    [
        from[0] + (to[0] - from[0]) * amount,
        from[1] + (to[1] - from[1]) * amount,
        from[2] + (to[2] - from[2]) * amount,
    ]
}

fn to_u8(value: f32) -> u8 {
    (value.clamp(0.0, 1.0) * 255.0).round() as u8
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn renders_rgba_icon_buffer() {
        let image = render_app_icon("forest", 32);
        assert_eq!(image.width, 32);
        assert_eq!(image.height, 32);
        assert_eq!(image.pixels.len(), 32 * 32 * 4);
        assert!(image.pixels.chunks_exact(4).any(|pixel| pixel[3] > 0));
    }

    #[test]
    fn rendered_icon_keeps_macos_visual_padding() {
        let image = render_app_icon_with_inset("default", 512, MACOS_ICON_CONTENT_INSET_RATIO);
        let mut min_x = image.width;
        let mut min_y = image.height;
        let mut max_x = 0;
        let mut max_y = 0;
        for y in 0..image.height {
            for x in 0..image.width {
                let alpha = image.pixels[((y * image.width + x) * 4 + 3) as usize];
                if alpha == 0 {
                    continue;
                }
                min_x = min_x.min(x);
                min_y = min_y.min(y);
                max_x = max_x.max(x);
                max_y = max_y.max(y);
            }
        }
        let visual_width = max_x - min_x + 1;
        let ratio = visual_width as f32 / image.width as f32;

        assert!((0.81..=0.83).contains(&ratio), "ratio={ratio}");
    }

    #[test]
    fn rendered_windows_icon_uses_full_canvas() {
        let image = render_app_icon_with_inset("default", 256, WINDOWS_ICON_CONTENT_INSET_RATIO);
        let mut min_x = image.width;
        let mut min_y = image.height;
        let mut max_x = 0;
        let mut max_y = 0;
        for y in 0..image.height {
            for x in 0..image.width {
                let alpha = image.pixels[((y * image.width + x) * 4 + 3) as usize];
                if alpha == 0 {
                    continue;
                }
                min_x = min_x.min(x);
                min_y = min_y.min(y);
                max_x = max_x.max(x);
                max_y = max_y.max(y);
            }
        }

        assert_eq!(min_x, 0);
        assert_eq!(min_y, 0);
        assert_eq!(max_x, image.width - 1);
        assert_eq!(max_y, image.height - 1);
    }

    #[test]
    fn default_icon_loads_bundled_png() {
        let path = crate::runtime_bridge::runtime_assets_path().join("icons/icon.png");
        assert!(
            path.is_file(),
            "bundled app icon missing: {}",
            path.display()
        );
        let image = render_app_icon("default", 128);
        assert_eq!(image.width, 128);
        assert_eq!(image.height, 128);
        assert_eq!(image.pixels.len(), 128 * 128 * 4);
        assert!(image.pixels.chunks_exact(4).any(|pixel| pixel[3] > 0));
        assert_eq!(
            image.pixels[3], 0,
            "macOS Dock icons keep transparent padding"
        );
    }

    #[test]
    fn color_styles_tint_the_bundled_png() {
        let forest = render_app_icon("forest", 128);
        let has_green_mark = forest
            .pixels
            .chunks_exact(4)
            .any(|pixel| pixel[3] > 80 && pixel[1] > pixel[0].saturating_add(20) && pixel[1] > 80);
        assert!(has_green_mark, "forest style should tint the chevron green");

        let sunset = render_app_icon("sunset", 128);
        let has_warm_mark = sunset
            .pixels
            .chunks_exact(4)
            .any(|pixel| pixel[3] > 80 && pixel[0] > pixel[2].saturating_add(20) && pixel[0] > 80);
        assert!(has_warm_mark, "sunset style should tint the chevron warm");
    }
}
