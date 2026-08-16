"""Builds the neumorphic promo set from the real mobile and desktop screenshots.

Every slide is 1920x1080 and shares one soft-UI language: a charcoal canvas lit
from the top left, raised slabs for the devices, detail cards cut straight out
of the real UI, and pills for the small labels.
"""

import os

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

W, H = 1920, 1080
HERE = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.join(HERE, 'screens')
OUT = HERE
ICON = os.path.join(HERE, 'app_icon.png')

BASE_TOP = (52, 52, 52)
BASE_BOTTOM = (34, 34, 34)
LIGHT = (66, 66, 66)
DARK = (16, 16, 16)
WELL = (38, 38, 38)
ACCENT = (229, 16, 35)
TEXT = (240, 240, 240)
MUTED = (150, 150, 150)

FONTS = '/usr/share/fonts/truetype/lato'

DESKTOP = 'win3.png'

# Regions cut from the full resolution desktop captures.
CROPS = {
    'carousel': ('E_nowplaying.png', (800, 340, 3040, 1140)),
    'controls': ('E_nowplaying.png', (840, 1330, 2860, 1900)),
    'queue': ('E_queue.png', (2820, 90, 3706, 1010)),
    'settings': ('E_settings.png', (2820, 90, 3706, 1650)),
    'grid': ('E_grid2.png', (930, 300, 2910, 1690)),
    'mini': (DESKTOP, (2480, 2040, 3660, 2330)),
}


def font(weight, size):
    return ImageFont.truetype(f'{FONTS}/Lato-{weight}.ttf', size)


# ---------------------------------------------------------------- primitives

def rr_mask(size, radius, supersample=4):
    """Anti-aliased rounded rectangle mask."""
    w, h = size
    big = Image.new('L', (w * supersample, h * supersample), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        [0, 0, w * supersample - 1, h * supersample - 1],
        radius=radius * supersample, fill=255,
    )
    return big.resize((w, h), Image.LANCZOS)


def vertical_gradient(size, top, bottom):
    w, h = size
    strip = Image.new('RGB', (1, h))
    pixels = strip.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        pixels[0, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return strip.resize((w, h), Image.BILINEAR)


def diagonal_gradient(size, light, dark):
    """Soft top-left to bottom-right sheen used on raised surfaces."""
    small = Image.new('RGB', (2, 2))
    mid = tuple((light[i] + dark[i]) // 2 for i in range(3))
    small.putpixel((0, 0), light)
    small.putpixel((1, 0), mid)
    small.putpixel((0, 1), mid)
    small.putpixel((1, 1), dark)
    return small.resize(size, Image.BICUBIC)


def soft_shadow(layer, mask, offset, blur, colour, opacity):
    """Paints one blurred copy of `mask` onto an RGBA layer."""
    shadow = mask.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * opacity))
    tint = Image.new('RGB', mask.size, colour)
    layer.alpha_composite(Image.merge('RGBA', (*tint.split(), shadow)), offset)


def raised_plate(size, radius, depth=18, blur=26, fill=None,
                 glow=None, glow_blur=70, glow_opacity=0.2):
    """Returns an RGBA slab with its neumorphic shadows baked in, plus its padding."""
    w, h = size
    pad = int(blur * 3 + depth + (glow_blur * 2 if glow else 0))
    canvas = Image.new('RGBA', (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    mask = rr_mask((w, h), radius)
    padded = Image.new('L', canvas.size, 0)
    padded.paste(mask, (pad, pad))

    if glow:
        halo = padded.filter(ImageFilter.GaussianBlur(glow_blur))
        halo = halo.point(lambda v: int(v * glow_opacity))
        tint = Image.new('RGB', canvas.size, glow)
        canvas.alpha_composite(Image.merge('RGBA', (*tint.split(), halo)))

    soft_shadow(canvas, padded, (depth, depth), blur, DARK, 0.85)
    soft_shadow(canvas, padded, (-depth, -depth), blur, LIGHT, 0.4)

    body = fill or diagonal_gradient((w, h), (58, 58, 58), (36, 36, 36))
    canvas.paste(body, (pad, pad), mask)
    return canvas, pad


def inner_shadow(canvas, box, radius, colour, offset, blur, opacity):
    """Draws a shadow inside the rounded shape at `box`."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    mask = rr_mask((w, h), radius)
    shifted = Image.new('L', (w, h), 255)
    shifted.paste(ImageChops.invert(mask), offset)
    shade = ImageChops.multiply(shifted.filter(ImageFilter.GaussianBlur(blur)), mask)
    shade = shade.point(lambda v: int(v * opacity))
    tint = Image.new('RGB', (w, h), colour)
    canvas.alpha_composite(Image.merge('RGBA', (*tint.split(), shade)), (x0, y0))


def well(canvas, box, radius, fill=WELL, depth=10, blur=14):
    """Recessed panel: darker fill with an inner top-left shadow."""
    x0, y0, x1, y1 = box
    mask = rr_mask((x1 - x0, y1 - y0), radius)
    canvas.paste(Image.new('RGB', mask.size, fill), (x0, y0), mask)
    inner_shadow(canvas, box, radius, DARK, (depth, depth), blur, 0.85)
    inner_shadow(canvas, box, radius, LIGHT, (-depth, -depth), blur, 0.3)


# -------------------------------------------------------------------- canvas

def new_canvas(rings=None):
    canvas = Image.new('RGBA', (W, H), BASE_TOP + (255,))
    canvas.paste(vertical_gradient((W, H), BASE_TOP, BASE_BOTTOM))

    glow = Image.new('L', (W, H), 0)
    ImageDraw.Draw(glow).ellipse([-500, -700, 1200, 700], fill=48)
    canvas.alpha_composite(Image.merge('RGBA', (
        *Image.new('RGB', (W, H), (92, 92, 92)).split(),
        glow.filter(ImageFilter.GaussianBlur(220)))))

    if rings:
        (cx, cy), radius = rings
        overlay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        draw = ImageDraw.Draw(overlay)
        for step in range(10):
            r = radius - step * 52
            if r <= 40:
                break
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255, 11), width=2)
        canvas.alpha_composite(overlay.filter(ImageFilter.GaussianBlur(0.7)))
    return canvas


def place(canvas, plate_pad, position):
    plate, pad = plate_pad
    canvas.alpha_composite(plate, (position[0] - pad, position[1] - pad))


# ------------------------------------------------------------------- devices

def screenshot(name):
    """Loads a capture and lifts it slightly so the dark UI reads on the canvas."""
    shot = Image.open(f'{SHOTS}/{name}').convert('RGB')
    shot = ImageEnhance.Brightness(shot).enhance(1.08)
    return ImageEnhance.Contrast(shot).enhance(1.05)


def phone(name, height, glow_opacity=0.22):
    """Frames a real phone screenshot in a soft slab."""
    shot = screenshot(name)
    bezel = max(6, height // 95)
    screen_h = height - bezel * 2
    screen_w = round(shot.width * screen_h / shot.height)
    shot = shot.resize((screen_w, screen_h), Image.LANCZOS)

    width = screen_w + bezel * 2
    radius = max(18, round(width * 0.075))
    plate, pad = raised_plate((width, height), radius, depth=14, blur=28,
                              glow=ACCENT, glow_blur=70, glow_opacity=glow_opacity)
    inner_radius = max(12, radius - bezel)
    plate.paste(shot, (pad + bezel, pad + bezel), rr_mask((screen_w, screen_h), inner_radius))
    inner_shadow(plate, (pad + bezel, pad + bezel, pad + bezel + screen_w, pad + bezel + screen_h),
                 inner_radius, DARK, (5, 5), 7, 0.65)
    return plate, pad


def window(name, width, glow_opacity=0.14):
    """Frames a real desktop window capture in a soft slab."""
    shot = screenshot(name)
    bezel = max(5, width // 230)
    screen_w = width - bezel * 2
    screen_h = round(shot.height * screen_w / shot.width)
    shot = shot.resize((screen_w, screen_h), Image.LANCZOS)

    plate, pad = raised_plate((width, screen_h + bezel * 2), max(14, round(width * 0.015)),
                              depth=20, blur=38, glow=ACCENT, glow_blur=95,
                              glow_opacity=glow_opacity)
    radius = max(10, round(width * 0.012))
    plate.paste(shot, (pad + bezel, pad + bezel), rr_mask((screen_w, screen_h), radius))
    inner_shadow(plate, (pad + bezel, pad + bezel, pad + bezel + screen_w, pad + bezel + screen_h),
                 radius, DARK, (4, 4), 6, 0.55)
    return plate, pad


def detail(key, width, glow_opacity=0.0):
    """Frames a 1:1 crop of the real UI as a floating card."""
    name, box = CROPS[key]
    shot = screenshot(name).crop(box)
    height = round(shot.height * width / shot.width)
    shot = shot.resize((width, height), Image.LANCZOS)

    bezel = 14
    plate, pad = raised_plate((width + bezel * 2, height + bezel * 2), 30,
                              depth=16, blur=30, glow=ACCENT if glow_opacity else None,
                              glow_blur=80, glow_opacity=glow_opacity)
    plate.paste(shot, (pad + bezel, pad + bezel), rr_mask((width, height), 18))
    inner_shadow(plate, (pad + bezel, pad + bezel, pad + bezel + width, pad + bezel + height),
                 18, DARK, (5, 5), 8, 0.6)
    return plate, pad


# ---------------------------------------------------------------------- text

def tracked(canvas, xy, label, weight, size, colour, tracking=6, align='l'):
    """Draws letter-spaced text and returns its width."""
    face = font(weight, size)
    draw = ImageDraw.Draw(canvas)
    widths = [draw.textlength(char, font=face) for char in label]
    total = sum(widths) + tracking * (len(label) - 1)
    x = xy[0] - total if align == 'r' else xy[0] - total / 2 if align == 'm' else xy[0]
    for char, advance in zip(label, widths):
        draw.text((x, xy[1]), char, font=face, fill=colour, anchor='ls')
        x += advance + tracking
    return total


def lines(canvas, xy, rows, weight, size, colour, leading, align='l'):
    draw = ImageDraw.Draw(canvas)
    face = font(weight, size)
    anchor = {'l': 'ls', 'r': 'rs', 'm': 'ms'}[align]
    x, y = xy
    for row in rows:
        draw.text((x, y), row, font=face, fill=colour, anchor=anchor)
        y += leading
    return y


def eyebrow(canvas, xy, label, align='l'):
    """Accent dot plus tracked uppercase label."""
    shift = {'l': 30, 'm': 21, 'r': 0}[align]
    width = tracked(canvas, (xy[0] + shift, xy[1]),
                    label.upper(), 'Black', 21, ACCENT, tracking=5, align=align)
    dot_x = {'l': xy[0], 'm': xy[0] - (width + 42) / 2, 'r': xy[0] - width - 30}[align]
    ImageDraw.Draw(canvas).ellipse([dot_x, xy[1] - 13, dot_x + 12, xy[1] - 1], fill=ACCENT)


def pill(canvas, centre, label, size=23, padding=(30, 17), accent=False):
    """Raised capsule label."""
    face = font('Semibold', size)
    text_w = ImageDraw.Draw(canvas).textlength(label, font=face)
    w, h = round(text_w) + padding[0] * 2, size + padding[1] * 2
    plate, pad = raised_plate((w, h), h // 2, depth=7, blur=12,
                              fill=diagonal_gradient((w, h), (57, 57, 57), (39, 39, 39)))
    canvas.alpha_composite(plate, (centre[0] - w // 2 - pad, centre[1] - h // 2 - pad))
    ImageDraw.Draw(canvas).text((centre[0], centre[1] + 1), label, font=face,
                                fill=ACCENT if accent else (208, 208, 208), anchor='mm')
    return w


def pill_row(canvas, start, labels, gap=18, size=23, padding=(30, 17), align='l'):
    widths = [round(ImageDraw.Draw(canvas).textlength(label, font=font('Semibold', size)))
              + padding[0] * 2 for label in labels]
    total = sum(widths) + gap * (len(labels) - 1)
    x = {'l': start[0], 'm': start[0] - total // 2, 'r': start[0] - total}[align]
    for label, width in zip(labels, widths):
        pill(canvas, (x + width // 2, start[1]), label, size=size, padding=padding)
        x += width + gap
    return total


def footer(canvas):
    tracked(canvas, (110, H - 56), 'github.com/acornassociated-22/AcornPlayer',
            'Regular', 20, (98, 98, 98), tracking=1.6)
    pill(canvas, (W - 170, H - 64), 'v1.2.1', size=20, padding=(26, 14), accent=True)


def column(canvas, x, top, label, headline, body, chips=None, align='l'):
    """The shared text column, anchored left or right."""
    eyebrow(canvas, (x, top), label, align=align)
    y = lines(canvas, (x, top + 92), headline, 'Black', 58, TEXT, 72, align=align)
    y = lines(canvas, (x, y + 34), body, 'Light', 27, MUTED, 42, align=align)
    if chips:
        pill_row(canvas, (x, y + 48), chips, align=align)


# -------------------------------------------------------------------- slides

def slide_hero():
    canvas = new_canvas(rings=((1580, 250), 500))
    eyebrow(canvas, (110, 300), 'Acorn Player · local first')
    lines(canvas, (110, 412), ['Play it', 'locally.'], 'Black', 104, TEXT, 108)
    lines(canvas, (110, 600), [
        'A neumorphic player for the music you',
        'already own. No streaming, no account,',
        'no noise — just your folders.',
    ], 'Light', 30, MUTED, 46)
    pill_row(canvas, (110, 800), ['Linux', 'Windows', 'macOS', 'Android', 'iOS'])

    place(canvas, window(DESKTOP, 900), (990, 300))
    place(canvas, phone('m_03_nowplaying.png', 700), (830, 300))
    footer(canvas)
    return canvas


def slide_library():
    canvas = new_canvas()
    column(canvas, 110, 250, 'Library',
           ['Your whole', 'library,', 'one glance.'],
           ['Folder scan, SQLite index and', 'instant search — six tracks or', 'sixty thousand.'],
           ['List', 'Grid', 'Sort'])
    place(canvas, window(DESKTOP, 1020), (740, 140))
    place(canvas, detail('mini', 620), (1080, 690))
    footer(canvas)
    return canvas


def slide_now_playing():
    canvas = new_canvas(rings=((1400, 520), 430))
    column(canvas, 110, 230, 'Now playing',
           ['The platter spins,', 'the waveform', 'breathes.'],
           ['Swipeable vinyl carousel, waveform', 'seek bar and a radial volume dial.'],
           ['Repeat', 'Shuffle', 'Speed'])
    place(canvas, phone('m_03_nowplaying.png', 760), (830, 170))
    place(canvas, detail('carousel', 660), (1200, 220))
    place(canvas, detail('controls', 660), (1200, 570))
    footer(canvas)
    return canvas


def slide_grid():
    canvas = new_canvas(rings=((520, 620), 430))
    place(canvas, detail('grid', 900), (110, 320))
    place(canvas, phone('m_02_grid.png', 700), (1075, 300))
    column(canvas, 1810, 300, 'Vinyl grid',
           ['Every track', 'is a record.'],
           ['The playing card wears its', 'progress on the platter ring.'],
           ['Artwork', 'Progress ring'], align='r')
    footer(canvas)
    return canvas


def slide_queue():
    canvas = new_canvas()
    column(canvas, 110, 250, 'Queue',
           ['Drag the night', 'into order.'],
           ['Reorder, remove or jump straight to', 'a track — the queue is one tap away', 'on desktop and phone.'])
    place(canvas, detail('queue', 560), (860, 180))
    place(canvas, phone('m_04_queue.png', 720), (1490, 180))
    footer(canvas)
    return canvas


def slide_settings():
    canvas = new_canvas(rings=((1500, 700), 400))
    column(canvas, 110, 250, 'Settings',
           ['Tuned to', 'your taste.'],
           ['Dark, light or system. Five band', 'equalizer, languages, favorites —', 'all in one soft drawer.'],
           ['Themes', 'Equalizer', 'Languages'])
    place(canvas, detail('settings', 470), (880, 120))
    place(canvas, phone('m_05_settings.png', 720), (1420, 190))
    footer(canvas)
    return canvas


def slide_platforms():
    canvas = new_canvas(rings=((960, 340), 560))
    eyebrow(canvas, (960, 160), 'One codebase', align='m')
    lines(canvas, (960, 250), ['Five platforms, one feel.'], 'Black', 62, TEXT, 70, align='m')
    lines(canvas, (960, 306), ['Flutter · just_audio · Drift — the same soft UI everywhere'],
          'Light', 27, MUTED, 40, align='m')
    pill_row(canvas, (960, 405), ['Linux', 'Windows', 'macOS', 'Android', 'iOS'],
             gap=22, size=26, padding=(38, 20), align='m')

    place(canvas, window(DESKTOP, 840), (390, 460))
    place(canvas, phone('m_01_library_list.png', 540), (1300, 455))
    footer(canvas)
    return canvas


def slide_end_card():
    canvas = new_canvas(rings=((960, 460), 640))
    size = 190
    plate, pad = raised_plate((size + 56,) * 2, (size + 56) // 2, depth=16, blur=26,
                              glow=ACCENT, glow_blur=80, glow_opacity=0.3)
    plate.paste(Image.open(ICON).convert('RGB').resize((size, size), Image.LANCZOS),
                (pad + 28, pad + 28), rr_mask((size, size), 44))
    canvas.alpha_composite(plate, (960 - (size + 56) // 2 - pad, 250 - pad))

    tracked(canvas, (960, 570), 'ACORN PLAYER', 'Black', 52, TEXT, tracking=10, align='m')
    lines(canvas, (960, 636), ['Play it locally.'], 'Light', 34, MUTED, 44, align='m')
    pill_row(canvas, (960, 740), ['Free & open source', 'GPL-3.0', 'Flutter'], align='m')

    well(canvas, (630, 830, 1290, 906), 38)
    ImageDraw.Draw(canvas).text((960, 876), 'github.com/acornassociated-22/AcornPlayer',
                                font=font('Regular', 25), fill=(182, 182, 182), anchor='ms')
    tracked(canvas, (960, 980), 'ACORN ASSOCIATED · QAMISHLI · v1.2.1', 'Regular', 18,
            (100, 100, 100), tracking=3, align='m')
    return canvas


SLIDES = [
    ('promo-neu-01-hero.png', slide_hero),
    ('promo-neu-02-library.png', slide_library),
    ('promo-neu-03-now-playing.png', slide_now_playing),
    ('promo-neu-04-vinyl-grid.png', slide_grid),
    ('promo-neu-05-queue.png', slide_queue),
    ('promo-neu-06-settings.png', slide_settings),
    ('promo-neu-07-platforms.png', slide_platforms),
    ('promo-neu-08-end-card.png', slide_end_card),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, builder in SLIDES:
        image = builder().convert('RGB')
        image.save(f'{OUT}/{name}', optimize=True)
        print('built', name)


if __name__ == '__main__':
    main()
