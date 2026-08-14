use super::*;
use crate::app::scroll_compat::ScrollableElement;
use gpui::{Anchor, Rems};
use gpui_component::{
    Disableable, Sizable,
    button::Button,
    popover::Popover,
};

const CODUX_SELECT_TEXT_SIZE: Rems = Rems(0.875);
const CODUX_SELECT_LINE_HEIGHT: Rems = Rems(1.125);

#[derive(Clone)]
pub(in crate::app) struct CoduxSelectOption {
    pub(in crate::app) value: String,
    pub(in crate::app) label: SharedString,
}

impl CoduxSelectOption {
    pub(in crate::app) fn new(value: impl Into<String>, label: impl Into<SharedString>) -> Self {
        Self {
            value: value.into(),
            label: label.into(),
        }
    }
}

pub(in crate::app) struct CoduxSelectConfig {
    pub(in crate::app) id: String,
    pub(in crate::app) value: String,
    pub(in crate::app) options: Vec<CoduxSelectOption>,
    pub(in crate::app) placeholder: SharedString,
    pub(in crate::app) width: Length,
    pub(in crate::app) menu_width: Pixels,
    pub(in crate::app) disabled: bool,
}

type CoduxSelectAction = Rc<dyn Fn(&mut CoduxApp, String, &mut Window, &mut Context<CoduxApp>)>;

pub(in crate::app) fn codux_select(
    config: CoduxSelectConfig,
    cx: &mut Context<CoduxApp>,
    action: impl Fn(&mut CoduxApp, String, &mut Window, &mut Context<CoduxApp>) + 'static,
) -> AnyElement {
    let CoduxSelectConfig {
        id,
        value,
        options,
        placeholder,
        width,
        menu_width,
        disabled,
    } = config;
    let selected_index = options.iter().position(|item| item.value == value);
    let selected_label = selected_index
        .and_then(|index| options.get(index))
        .map(|item| item.label.clone())
        .unwrap_or(placeholder);
    let action: CoduxSelectAction = Rc::new(action);
    let selected_value = value;
    let app_entity = cx.entity();

    let trigger = Button::new(SharedString::from(format!("codux-select-trigger-{id}")))
        .outline()
        .small()
        .disabled(disabled)
        .w(width)
        .min_w(px(0.0))
        .child(
            div()
                .flex()
                .w_full()
                .min_w_0()
                .items_center()
                .justify_between()
                .gap_2()
                .child(
                    div()
                        .min_w_0()
                        .flex_1()
                        .truncate()
                        .text_size(CODUX_SELECT_TEXT_SIZE)
                        .line_height(CODUX_SELECT_LINE_HEIGHT)
                        .text_color(if selected_index.is_some() {
                            color(theme::TEXT)
                        } else {
                            cx.theme().muted_foreground
                        })
                        .child(selected_label),
                )
                .child(
                    Icon::new(HeroIconName::ChevronDown)
                        .size_3()
                        .flex_shrink_0()
                        .text_color(if disabled {
                            cx.theme().foreground.opacity(0.3)
                        } else {
                            cx.theme().foreground.opacity(0.5)
                        }),
                ),
        );

    if disabled {
        return trigger.into_any_element();
    }

    Popover::new(SharedString::from(format!("codux-select-menu-{id}")))
        .w(width)
        .anchor(Anchor::TopRight)
        .appearance(false)
        .trigger(trigger)
        .content(move |_, _, cx| {
            let popover = cx.entity();
            let accent = cx.theme().accent;
            let accent_fg = cx.theme().accent_foreground;
            let hover = cx.theme().list_hover;
            let fg = color(theme::TEXT);
            div()
                .w(menu_width)
                .max_h(px(280.0))
                .overflow_y_scrollbar()
                .rounded(px(8.0))
                .border_1()
                .border_color(cx.theme().border)
                .bg(cx.theme().popover)
                .shadow_md()
                .p(px(4.0))
                .flex()
                .flex_col()
                .children(options.iter().map(|item| {
                    let value = item.value.clone();
                    let selected = value == selected_value;
                    let action = action.clone();
                    let app_entity = app_entity.clone();
                    let popover = popover.clone();
                    let label = item.label.clone();
                    div()
                        .id(SharedString::from(format!("codux-select-option-{value}")))
                        .w_full()
                        .h(px(22.0))
                        .px(px(8.0))
                        .rounded(px(5.0))
                        .flex()
                        .items_center()
                        .gap(px(6.0))
                        .cursor_pointer()
                        .text_size(CODUX_SELECT_TEXT_SIZE)
                        .line_height(CODUX_SELECT_LINE_HEIGHT)
                        .text_color(if selected { accent_fg } else { fg })
                        .bg(if selected {
                            accent
                        } else {
                            cx.theme().transparent
                        })
                        .hover(move |style| {
                            if selected {
                                style
                            } else {
                                style.bg(hover)
                            }
                        })
                        .on_click(move |_, window, cx| {
                            cx.update_entity(&app_entity, |app, cx| {
                                action(app, value.clone(), window, cx);
                                cx.notify();
                            });
                            popover.update(cx, |state, cx| state.dismiss(window, cx));
                        })
                        .child(
                            div()
                                .w(px(12.0))
                                .flex_shrink_0()
                                .child(if selected {
                                    Icon::new(HeroIconName::Check)
                                        .size_3()
                                        .text_color(accent_fg)
                                        .into_any_element()
                                } else {
                                    div().into_any_element()
                                }),
                        )
                        .child(
                            div()
                                .min_w_0()
                                .flex_1()
                                .truncate()
                                .child(label),
                        )
                        .into_any_element()
                }))
        })
        .into_any_element()
}
