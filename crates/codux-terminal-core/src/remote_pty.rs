use std::collections::BTreeMap;

use crate::{HeadlessTerminalScreen, TerminalScreenSnapshot, TerminalSequence};

/// Upper bound on live frames held while awaiting a baseline. A baseline that
/// never arrives (host torn down mid-request) would otherwise let the held
/// buffers grow without limit; past the cap we drop the oldest held frames.
const MAX_HELD_LIVE: usize = 2048;

/// Metadata for a viewport that was rendered by the host's authoritative
/// terminal screen. The local screen still owns the decoded cells, but these
/// values keep the consumer's renderer aware that those cells represent a
/// remote scrollback position rather than the local replay position.
#[derive(Clone, Copy, Debug)]
struct RemoteViewportMetadata {
    cols: usize,
    rows: usize,
    total_lines: usize,
    display_offset: usize,
    margin_rows: usize,
    margin_rows_below: usize,
}

pub struct RemotePtySession<T> {
    max_cached_chars: usize,
    content: String,
    buffer_length: usize,
    buffer_end: Option<usize>,
    sequence: TerminalSequence,
    history_screen: HeadlessTerminalScreen,
    remote_viewport: Option<RemoteViewportMetadata>,
    awaiting_baseline: bool,
    held_sequenced_live: BTreeMap<TerminalSequence, T>,
    held_unsequenced_live: Vec<T>,
}

impl<T> RemotePtySession<T> {
    pub fn new(max_cached_chars: usize) -> Self {
        Self {
            max_cached_chars,
            content: String::new(),
            buffer_length: 0,
            buffer_end: None,
            sequence: 0,
            history_screen: HeadlessTerminalScreen::new(80, 24, 2_000),
            remote_viewport: None,
            awaiting_baseline: false,
            held_sequenced_live: BTreeMap::new(),
            held_unsequenced_live: Vec::new(),
        }
    }

    pub fn content(&self) -> &str {
        &self.content
    }

    pub fn buffer_length(&self) -> usize {
        self.buffer_length
    }

    #[cfg(test)]
    pub(crate) fn buffer_end(&self) -> Option<usize> {
        self.buffer_end
    }

    pub fn sequence(&self) -> TerminalSequence {
        self.sequence
    }

    pub fn is_restoring_baseline(&self) -> bool {
        self.awaiting_baseline
    }

    pub fn screen_snapshot(&self) -> TerminalScreenSnapshot {
        // One screen owns both the replayed history and authoritative visible
        // keyframes, so live output, scrolling, and baseline restores cannot
        // diverge into separate render states.
        let mut snapshot = self.history_screen.snapshot();
        if let Some(viewport) = self.remote_viewport {
            snapshot.cols = viewport.cols;
            snapshot.rows = viewport.rows;
            snapshot.total_lines = viewport.total_lines;
            snapshot.display_offset = viewport.display_offset;
            snapshot.margin_rows = viewport.margin_rows;
            snapshot.margin_rows_below = viewport.margin_rows_below;
        }
        snapshot
    }

    pub fn has_remote_viewport(&self) -> bool {
        self.remote_viewport.is_some()
    }

    /// Replace the visible grid with a host-rendered viewport keyframe. The
    /// raw cache remains intact for reconnect/baseline recovery; the remote
    /// metadata tells the UI how to request the adjacent viewport from the
    /// host instead of trying to reflow raw ANSI locally (which is incorrect
    /// for full-screen TUIs).
    pub fn apply_remote_viewport_snapshot(
        &mut self,
        screen_data: &str,
        screen_wrapped_rows: Option<&[bool]>,
        cols: usize,
        rows: usize,
        total_lines: usize,
        display_offset: usize,
        margin_rows: usize,
        margin_rows_below: usize,
    ) {
        if cols > 0 && rows > 0 {
            let current = self.history_screen.snapshot();
            if current.cols != cols || current.rows != rows {
                self.history_screen.resize(cols, rows);
            }
        }
        self.history_screen.scroll_to_bottom();
        if !screen_data.is_empty() {
            self.history_screen
                .replace_visible_with_keyframe(screen_data.as_bytes());
            if let Some(wrapped_rows) = screen_wrapped_rows {
                self.history_screen
                    .restore_visible_wrapped_rows(wrapped_rows);
            }
        }
        self.remote_viewport = Some(RemoteViewportMetadata {
            cols: cols.max(1),
            rows: rows.max(1),
            total_lines: total_lines.max(rows.max(1)),
            display_offset,
            margin_rows,
            margin_rows_below,
        });
    }

    pub fn resize_screen(&mut self, cols: usize, rows: usize) {
        let current = self.history_screen.snapshot();
        if current.cols == cols && current.rows == rows {
            // Viewport state is metadata layered over the same cell grid. A
            // repeated viewport-state notification with the same dimensions
            // must not throw away an in-flight/visible remote history page.
            return;
        }
        self.remote_viewport = None;
        self.history_screen.resize(cols, rows);
    }

    pub fn scroll_screen_pixels(&mut self, pixels: f64, cell_height: f64) {
        if !pixels.is_finite() || pixels == 0.0 || !cell_height.is_finite() || cell_height <= 0.0 {
            return;
        }
        self.history_screen.scroll_pixels(pixels, cell_height);
    }

    pub fn settle_screen_pixel_scroll(&mut self) {
        self.history_screen.settle_pixel_scroll();
    }

    pub fn require_baseline(&mut self) {
        self.remote_viewport = None;
        self.awaiting_baseline = true;
        self.held_sequenced_live.clear();
        self.held_unsequenced_live.clear();
    }

    pub fn reset_transient(&mut self, reset_sequence: bool) {
        self.remote_viewport = None;
        self.awaiting_baseline = false;
        self.held_sequenced_live.clear();
        self.held_unsequenced_live.clear();
        if reset_sequence {
            self.sequence = 0;
            self.buffer_end = None;
        }
    }

    pub fn hold_live(&mut self, sequence: Option<TerminalSequence>, output: T) -> bool {
        if !self.awaiting_baseline {
            return false;
        }
        if let Some(sequence) = sequence {
            self.held_sequenced_live.entry(sequence).or_insert(output);
            // Drop the oldest held frames past the cap. The baseline replay and
            // sequence-gap resync repair any resulting hole.
            while self.held_sequenced_live.len() > MAX_HELD_LIVE {
                let oldest = *self
                    .held_sequenced_live
                    .keys()
                    .next()
                    .expect("non-empty held buffer");
                self.held_sequenced_live.remove(&oldest);
            }
        } else {
            self.held_unsequenced_live.push(output);
            if self.held_unsequenced_live.len() > MAX_HELD_LIVE {
                let overflow = self.held_unsequenced_live.len() - MAX_HELD_LIVE;
                self.held_unsequenced_live.drain(0..overflow);
            }
        }
        true
    }

    pub fn replace_from_baseline(
        &mut self,
        content: &str,
        screen_data: Option<&str>,
        screen_wrapped_rows: Option<&[bool]>,
        buffer_length: Option<usize>,
        buffer_end: Option<usize>,
        sequence: Option<TerminalSequence>,
    ) -> Vec<T> {
        self.remote_viewport = None;
        // Preserve the user's scroll position across a baseline replace: a
        // resync (e.g. after a dropped frame) rebuilds the buffer, and snapping
        // back to the bottom mid-scroll is jarring. If the user was scrolled up
        // by N lines, restore that distance from the new bottom.
        let prev_offset = self.history_screen.display_offset();
        let previous_content = self.content.clone();
        let previous_buffer_end = self.buffer_end;
        let merged_content =
            merge_baseline_content(&previous_content, previous_buffer_end, content, buffer_end);
        // A screen keyframe is authoritative for the current viewport, but it
        // does not contain the whole scrollback. During a reconnect the host
        // often returns only the current AI/TUI screen, so clearing the local
        // screen here would throw away history the phone already received.
        // Keep that screen history while the absolute PTY watermark still
        // belongs to the same terminal lifetime. A host restart resets the
        // watermark, which intentionally falls through to a clean rebuild.
        let preserve_screen_history = screen_data.is_some()
            && !previous_content.is_empty()
            && same_terminal_lifetime(
                previous_content.chars().count(),
                previous_buffer_end,
                buffer_end,
            );
        self.content.clear();
        self.content.push_str(&merged_content);
        trim_cache_buffer(&mut self.content, self.max_cached_chars);
        if let Some(buffer_length) = buffer_length {
            self.buffer_length = buffer_length;
        }
        self.buffer_end = buffer_end;
        let mut rendered = preserve_screen_history;
        if !preserve_screen_history {
            self.history_screen.clear();
            if !self.content.is_empty() {
                self.history_screen.process(self.content.as_bytes());
                rendered = true;
            }
        }
        // Reconstruct the current screen from the host keyframe. An alt-screen
        // TUI (e.g. Claude) keeps its UI outside raw scrollback, while a normal
        // screen keyframe may overlap the end of that history. Replace the
        // visible grid in place so the keyframe never pushes its old viewport
        // (including blank rows and partial redraws) into scrollback again.
        if let Some(screen_data) = screen_data
            && !screen_data.is_empty()
        {
            self.history_screen
                .replace_visible_with_keyframe(screen_data.as_bytes());
            if let Some(wrapped_rows) = screen_wrapped_rows {
                self.history_screen
                    .restore_visible_wrapped_rows(wrapped_rows);
            }
            rendered = true;
        }
        if rendered {
            self.history_screen.scroll_to_bottom();
            if prev_offset > 0 {
                self.history_screen.scroll_to_offset(prev_offset);
                // A rebuilt buffer can be shorter than the old scroll distance;
                // a clamped restore would strand the view at the very top, so
                // fall back to the bottom when the exact spot no longer exists.
                if self.history_screen.display_offset() != prev_offset {
                    self.history_screen.scroll_to_bottom();
                }
            }
        }
        let base_sequence = sequence.unwrap_or(self.sequence);
        self.sequence = base_sequence;
        self.awaiting_baseline = false;

        let mut replay = Vec::new();
        let held_sequenced_live = std::mem::take(&mut self.held_sequenced_live);
        for (sequence, output) in held_sequenced_live {
            if sequence > base_sequence {
                replay.push(output);
            }
        }
        replay.append(&mut self.held_unsequenced_live);
        replay
    }

    pub fn complete_empty_baseline(&mut self, sequence: Option<TerminalSequence>) -> Vec<T> {
        self.remote_viewport = None;
        let base_sequence = sequence.unwrap_or(self.sequence);
        self.sequence = base_sequence;
        self.awaiting_baseline = false;

        let mut replay = Vec::new();
        let held_sequenced_live = std::mem::take(&mut self.held_sequenced_live);
        for (sequence, output) in held_sequenced_live {
            if sequence > base_sequence {
                replay.push(output);
            }
        }
        replay.append(&mut self.held_unsequenced_live);
        replay
    }

    pub fn append_live(
        &mut self,
        data: &str,
        buffer_length: Option<usize>,
        buffer_end: Option<usize>,
        sequence: Option<TerminalSequence>,
    ) {
        // Keep a remote history page stable while live output continues to
        // arrive. Clearing the viewport here makes a high-latency page request
        // race with the output stream: the next frame snaps back to the local
        // replay (or a partially rebuilt blank screen), producing gaps between
        // pages. A page at offset zero is the live tail, so it should continue
        // to follow output normally; only an older page is pinned.
        let preserve_remote_viewport = self
            .remote_viewport
            .is_some_and(|viewport| viewport.display_offset > 0);
        if !preserve_remote_viewport {
            self.remote_viewport = None;
        }
        let data_chars = data.chars().count();
        let previous_end = self.buffer_end;
        let covered_chars = buffer_end
            .zip(previous_end)
            .map(|(buffer_end, previous_end)| {
                let frame_start = buffer_end.saturating_sub(data_chars);
                previous_end.saturating_sub(frame_start).min(data_chars)
            })
            .unwrap_or(0);
        let uncovered = if covered_chars == 0 {
            data
        } else {
            let start = data
                .char_indices()
                .nth(covered_chars)
                .map(|(index, _)| index)
                .unwrap_or(data.len());
            &data[start..]
        };
        if !uncovered.is_empty() {
            // The live view is the raw PTY history reflowed to the consumer's
            // grid. A baseline can already include a queued live frame, so use
            // the host's absolute history watermark to append only the suffix
            // not covered by that baseline. Follow the bottom only if we were
            // already there, so a user scrolled up into history stays put.
            push_cache_buffer(&mut self.content, uncovered, self.max_cached_chars);
            if !preserve_remote_viewport {
                let was_at_bottom = self.history_screen.display_offset() == 0;
                self.history_screen.process(uncovered.as_bytes());
                if was_at_bottom {
                    self.history_screen.scroll_to_bottom();
                }
            }
        }
        let advances_watermark = match (previous_end, buffer_end) {
            (Some(previous), Some(current)) => current > previous,
            _ => true,
        };
        if advances_watermark {
            self.buffer_length = buffer_length.unwrap_or_else(|| {
                self.buffer_length
                    .saturating_add(data_chars.saturating_sub(covered_chars))
            });
        }
        self.buffer_end = match (previous_end, buffer_end) {
            (Some(previous), Some(current)) => Some(previous.max(current)),
            (None, Some(current)) => Some(current),
            (_, None) => None,
        };
        if let Some(sequence) = sequence {
            self.sequence = sequence;
        }
    }

    pub fn clear(&mut self) {
        self.remote_viewport = None;
        self.content.clear();
        self.buffer_length = 0;
        self.buffer_end = None;
        self.sequence = 0;
        self.history_screen.clear();
        self.reset_transient(false);
    }
}

/// Decide whether a baseline belongs to the same append-only PTY lifetime as
/// the locally cached output. The host's [buffer_end] is an absolute character
/// watermark; when a restarted host reports a lower watermark, old screen
/// history must not leak into the new session.
fn same_terminal_lifetime(
    previous_content_chars: usize,
    previous_buffer_end: Option<usize>,
    next_buffer_end: Option<usize>,
) -> bool {
    let (Some(previous_end), Some(next_end)) = (previous_buffer_end, next_buffer_end) else {
        return false;
    };
    let previous_start = previous_end.saturating_sub(previous_content_chars);
    next_end >= previous_start
}

/// Merge overlapping append-only history windows across a reconnect. A tail
/// baseline can start inside the cached window; replacing it verbatim would
/// discard the older lines the phone already has, while concatenating blindly
/// would duplicate the overlap. If the windows cannot be aligned, the new
/// host baseline remains authoritative and the screen keyframe path can still
/// preserve the old rendered scrollback for the same terminal lifetime.
fn merge_baseline_content(
    previous: &str,
    previous_buffer_end: Option<usize>,
    next: &str,
    next_buffer_end: Option<usize>,
) -> String {
    if previous.is_empty() || next.is_empty() {
        if next.is_empty()
            && !previous.is_empty()
            && same_terminal_lifetime(
                previous.chars().count(),
                previous_buffer_end,
                next_buffer_end,
            )
        {
            return previous.to_string();
        }
        return next.to_string();
    }
    let (Some(previous_end), Some(next_end)) = (previous_buffer_end, next_buffer_end) else {
        return next.to_string();
    };
    let previous_chars = previous.chars().count();
    let next_chars = next.chars().count();
    let previous_start = previous_end.saturating_sub(previous_chars);
    let next_start = next_end.saturating_sub(next_chars);

    // A delayed/stale baseline that is fully covered by the local cache must
    // not roll the screen backward.
    if next_start >= previous_start && next_end <= previous_end {
        return previous.to_string();
    }
    if next_end < previous_start || previous_end < next_start {
        return next.to_string();
    }

    if next_start >= previous_start {
        let overlap = previous_end.saturating_sub(next_start).min(next_chars);
        if text_suffix_equals_prefix(previous, next, overlap) {
            return append_after_chars(previous, next, overlap);
        }
    } else if next_end >= previous_start {
        let overlap = next_end.saturating_sub(previous_start).min(previous_chars);
        if text_suffix_equals_prefix(next, previous, overlap) {
            return append_after_chars(next, previous, overlap);
        }
    }

    next.to_string()
}

fn text_suffix_equals_prefix(left: &str, right: &str, chars: usize) -> bool {
    if chars == 0 {
        return true;
    }
    let left_start = left.chars().count().saturating_sub(chars);
    left.chars().skip(left_start).eq(right.chars().take(chars))
}

fn append_after_chars(prefix: &str, suffix: &str, overlap: usize) -> String {
    let suffix_start = suffix
        .char_indices()
        .nth(overlap)
        .map(|(index, _)| index)
        .unwrap_or(suffix.len());
    let mut merged = String::with_capacity(prefix.len() + suffix.len() - suffix_start);
    merged.push_str(prefix);
    merged.push_str(&suffix[suffix_start..]);
    merged
}

/// Trailing line budget for the cached raw history and native ANSI replay.
///
/// The native terminal emulator (iOS SwiftTerm / Android) keeps its own
/// ~500-line scrollback, so caching far more than it can hold only makes the
/// full re-feed on a session switch needlessly large (the emulator parses it
/// all and then discards everything past its scrollback). Bounding the cache
/// a little above that scrollback keeps a switch's `replace` small while still
/// fully repopulating the emulator.
const MAX_CACHED_LINES: usize = 600;

/// Append `data` to `buffer`, then trim the front to the cache budget. Appends
/// in place (no per-frame reallocation of the whole buffer).
fn push_cache_buffer(buffer: &mut String, data: &str, max_chars: usize) {
    buffer.push_str(data);
    trim_cache_buffer(buffer, max_chars);
}

/// Trim the front of `buffer` in place so it keeps at most [`MAX_CACHED_LINES`]
/// trailing newline-delimited lines and at most `max_chars` characters.
///
/// The line budget is the primary bound -- it matches the native emulator's
/// scrollback so a restore re-feeds only what the emulator can hold.
/// `max_chars` is a safety ceiling that also bounds pathologically long lines.
/// Both scans are bounded by the size of the retained window (~600 lines), not
/// the whole buffer, so the steady-state live path stays amortized O(appended
/// bytes) rather than O(buffer length) per frame.
fn trim_cache_buffer(buffer: &mut String, max_chars: usize) {
    if max_chars == 0 {
        buffer.clear();
        return;
    }
    let bytes = buffer.as_bytes();
    let len = bytes.len();

    // Line budget: walk back from the end until we have passed
    // MAX_CACHED_LINES newlines, then cut just after that newline (always a
    // UTF-8 and line boundary, so the kept stream starts at a clean line).
    let mut cut = 0usize;
    let mut seen = 0usize;
    let mut i = len;
    while i > 0 {
        i -= 1;
        if bytes[i] == b'\n' {
            seen += 1;
            if seen > MAX_CACHED_LINES {
                cut = i + 1;
                break;
            }
        }
    }

    // Char ceiling: only scan when the retained window is still over the byte
    // ceiling (bytes >= chars), then drop to 7/8 of the ceiling so the
    // pathological long-line case re-trims rarely rather than every frame.
    if len - cut > max_chars {
        let remaining = &buffer[cut..];
        let total = remaining.chars().count();
        if total > max_chars {
            let target = max_chars.saturating_sub(max_chars / 8).max(1);
            let drop = total - target;
            let extra = remaining
                .char_indices()
                .nth(drop)
                .map(|(index, _)| index)
                .unwrap_or(remaining.len());
            cut += extra;
        }
    }

    if cut > 0 {
        buffer.drain(..cut);
    }
}
