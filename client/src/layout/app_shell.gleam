import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

pub fn view(header: Element(msg), page: Element(msg)) -> Element(msg) {
  div([attribute.class("min-h-screen overflow-hidden")], [header, page])
}
