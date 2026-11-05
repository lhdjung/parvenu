# Draws man/figures/logo.png; run from the package root. The fonts are
# macOS system fonts, so other systems will fall back to another serif.

pts <- function(...) {
  p <- matrix(c(...), ncol = 2, byrow = TRUE)
  paste(sprintf("%.1f,%.1f", p[, 1], p[, 2]), collapse = " ")
}
# A shard: one filled polygon, almost always a triangle.
S <- function(col, ...) {
  sprintf(
    '<polygon points="%s" fill="%s" stroke="%s" stroke-width="0.8" stroke-linejoin="round"/>',
    pts(...),
    col,
    col
  )
}
# A fan of triangles around a centre, for round things.
fan <- function(cx, cy, r, n, cols, from = 0, to = 2 * pi, ry = r) {
  a <- seq(from, to, length.out = n + 1)
  x <- cx + r * cos(a)
  y <- cy + ry * sin(a)
  vapply(
    seq_len(n),
    function(i) {
      S(
        cols[(i - 1) %% length(cols) + 1],
        cx,
        cy,
        x[i],
        y[i],
        x[i + 1],
        y[i + 1]
      )
    },
    ""
  )
}

# The face, turned three-quarters to the left: outline points A-N, inner
# points O-X. Each triangle is one plane. The turn shows a sliver of the
# far eye beside the nose.
# fmt: skip
p <- list(
  A = c(196, 150), B = c(172, 184), C = c(178, 206), D = c(140, 262),
  E = c(168, 268), F = c(164, 284), G = c(172, 294), H = c(166, 306),
  I = c(180, 349), J = c(226, 362), K = c(290, 322), L = c(318, 290),
  M = c(326, 200), N = c(290, 150), O = c(228, 206), P = c(262, 254),
  Q = c(218, 294), R = c(242, 318), X = c(202, 210)
)
# fmt: skip
planes <- list(
  list("ABX", "#fbefc0"),
  list("AXO", "#f6e6a8"),
  list("AON", "#f0d98f"),
  list("NOP", "#e4cf86"),
  list("NPM", "#d4b46a"),
  list("BCX", "#e8d48e"),
  list("CDX", "#e4c97c"),
  list("XDE", "#fbefc0"),
  list("XEP", "#f0d98f"),
  list("XPO", "#e8c878"),
  list("EQP", "#f2bd92"),
  list("EFG", "#ecc58a"),
  list("EGQ", "#f6e3a4"),
  list("GHQ", "#f6e6a8"),
  list("HIQ", "#efd894"),
  list("QIR", "#e0ca82"),
  list("QRP", "#e8d48e"),
  list("PRK", "#d6c472"),
  list("PKL", "#ccb662"),
  list("PLM", "#d8bc72"),
  list("IJR", "#e8d48e"),
  list("RJK", "#c8b264")
)
face <- vapply(
  planes,
  function(pl) {
    v <- lapply(strsplit(pl[[1]], "")[[1]], function(k) p[[k]])
    do.call(S, c(list(pl[[2]]), v))
  },
  ""
)

# Narrow, sloping shoulders.
coat <- c(
  S("#24481b", 298, 372, 470, 452, 330, 620),
  S("#2f5a22", 470, 452, 560, 620, 330, 620),
  S("#335f23", 120, 416, 240, 430, 130, 620),
  S("#2a5320", 240, 430, 298, 372, 330, 620),
  S("#1f4018", 240, 430, 330, 620, 130, 620),
  S("#3c6d26", 262, 420, 306, 384, 292, 520),
  S("#2c5822", 40, 440, 160, 420, 70, 600)
)
# Pinstripes: faint parallel lines, the "par" in parvenu, clipped to the coat.
pinstripes <- c(
  sprintf('<clipPath id="coat">%s</clipPath>', paste(coat, collapse = "")),
  '<g clip-path="url(#coat)" stroke="#e7c53a" stroke-width="1.6" stroke-opacity="0.45">',
  sprintf(
    '<line x1="%d" y1="360" x2="%d" y2="620"/>',
    seq(0, 560, 20),
    seq(0, 560, 20) - 24
  ),
  '</g>',
  S("#e7c53a", 198, 420, 238, 426, 216, 452)
)

# Pocket watch on a short gold chain: the package's fast code.
watch <- c(
  '<polyline points="114,443 122,452 134,454 146,449 156,440" fill="none" stroke="#f0c53a" stroke-width="2.2" stroke-linejoin="round"/>',
  S("#e9c13b", 110, 446, 118, 446, 114, 439),
  fan(114, 464, 18, 12, c("#e9c13b", "#c99a24")),
  fan(114, 464, 13, 12, "#fbf6dc"),
  S("#2b2412", 113, 464, 115, 464, 114, 454),
  S("#2b2412", 114, 463, 114, 465, 124, 468)
)

# Buttonhole flower on the lapel.
flower <- c(
  vapply(
    0:4 * 2 * pi / 5 - pi / 2,
    function(a) {
      S(
        "#f4d03f",
        318,
        414,
        318 + 13 * cos(a - 0.3),
        414 + 13 * sin(a - 0.3),
        318 + 13 * cos(a + 0.3),
        414 + 13 * sin(a + 0.3)
      )
    },
    ""
  ),
  fan(318, 414, 4, 5, "#c8611f")
)

neck_collar <- c(
  S("#c3ae63", 230, 340, 296, 306, 292, 392),
  S("#b09a52", 230, 340, 292, 392, 232, 400),
  S("#f6f0cf", 210, 356, 318, 316, 232, 404),
  S("#e2dcb4", 318, 316, 300, 388, 232, 404),
  S("#fbf7e2", 212, 358, 156, 342, 232, 404)
)

hair <- c(
  S("#8a3f17", 286, 150, 340, 160, 324, 238),
  S("#6e3214", 292, 190, 301, 188, 296, 234)
)

# A closed-mouth smile: a thin crescent along one curve, built as a strip
# of triangles that is thickest in the middle and tapers at both ends.
smile <- local({
  t <- seq(0, 1, length.out = 9)
  x <- (1 - t)^2 * 168 + 2 * (1 - t) * t * 204 + t^2 * 240
  y <- (1 - t)^2 * 289 + 2 * (1 - t) * t * 303 + t^2 * 277
  w <- 0.8 + 3.2 * sin(pi * t)
  top <- cbind(x, y - w / 2)
  bot <- cbind(x, y + w / 2)
  unlist(lapply(1:8, function(i) {
    c(
      S("#b04a2c", top[i, ], bot[i, ], top[i + 1, ]),
      S("#b04a2c", top[i + 1, ], bot[i, ], bot[i + 1, ])
    )
  }))
})

features <- c(
  # ear
  S("#d8b45e", 306, 224, 330, 250, 304, 284),
  S("#b07f38", 310, 240, 320, 252, 308, 272),
  # eyes, drawn from the front and close in size so the gaze stays easy;
  # the lids rest on the irises for a relaxed look
  S("#7a5232", 200, 208, 254, 200, 230, 189),
  S("#fbf6dc", 204, 207, 250, 201, 230, 193),
  S("#f1e9c4", 204, 207, 250, 201, 226, 215),
  S("#3d6b2a", 229, 194, 236, 203, 229, 211, 222, 203),
  S("#16200e", 229, 199, 233, 203, 229, 207, 225, 203),
  S("#ffffff", 225, 197, 229, 197, 227, 200),
  S("#7a5232", 163, 208, 197, 203, 183, 196),
  S("#fbf6dc", 166, 208, 194, 204, 183, 199),
  S("#f1e9c4", 166, 208, 194, 204, 184, 214),
  S("#3d6b2a", 185, 200, 190, 206, 185, 212, 180, 206),
  S("#16200e", 185, 203, 188, 206, 185, 209, 182, 206),
  # brows, softly raised
  S("#6e3214", 202, 182, 262, 176, 206, 178),
  S("#6e3214", 160, 192, 194, 186, 162, 196),
  smile
)

hat <- c(
  '<g transform="translate(0,-12) rotate(-8 258 150)">',
  fan(
    258,
    140,
    86,
    6,
    c("#7d4522", "#5a2f16", "#8f5229", "#6b3a1c"),
    pi,
    2 * pi,
    ry = 72
  ),
  # band: two parallel stripes
  S("#2f5a22", 174, 125, 342, 125, 173, 131),
  S("#3c6d26", 342, 125, 343, 131, 173, 131),
  S("#2f5a22", 173, 135, 343, 135, 172, 141),
  S("#3c6d26", 343, 135, 344, 141, 172, 141),
  S("#6b3a1c", 136, 136, 258, 140, 156, 160),
  S("#4f2a13", 156, 160, 258, 140, 258, 166),
  S("#7d4522", 258, 140, 378, 130, 258, 166),
  S("#5a2f16", 378, 130, 364, 158, 258, 166),
  '</g>'
)

cravat <- c(
  S("#d2691e", 140, 386, 222, 408, 160, 436),
  S("#b3531a", 222, 408, 300, 388, 272, 434),
  S("#e08a35", 202, 398, 240, 402, 218, 448),
  S("#8e3b12", 210, 400, 230, 403, 220, 416),
  S("#f3d34a", 218, 420, 224, 428, 218, 436, 212, 428)
)

hexs <- pts(260, 10, 511.1, 155, 511.1, 445, 260, 590, 8.9, 445, 8.9, 155)
font <- 'font-family="Bodoni 72 Oldstyle, Didot, Baskerville, serif" font-style="italic" font-size="70" fill="#f4e07c" stroke="#24481b" stroke-width="6" paint-order="stroke"'

svg <- c(
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 520 600" width="520" height="600">',
  '<defs>',
  '<linearGradient id="bg" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stop-color="#8db43c"/><stop offset="1" stop-color="#4d7d28"/></linearGradient>',
  sprintf('<clipPath id="hex"><polygon points="%s"/></clipPath>', hexs),
  '</defs>',
  '<g clip-path="url(#hex)">',
  '<rect width="520" height="600" fill="url(#bg)"/>',
  coat,
  pinstripes,
  watch,
  flower,
  neck_collar,
  hair,
  face,
  features,
  hat,
  cravat,
  sprintf('<text x="36" y="248" text-anchor="start" %s>par</text>', font),
  sprintf('<text x="478" y="334" text-anchor="end" %s>venu</text>', font),
  '</g>',
  sprintf(
    '<polygon points="%s" fill="none" stroke="#d9a62a" stroke-width="16" stroke-linejoin="round"/>',
    hexs
  ),
  '</svg>'
)
svg_path <- tempfile(fileext = ".svg")
writeLines(svg, svg_path)
rsvg::rsvg_png(svg_path, "man/figures/logo.png", width = 1040)
