"""Mechanical component separation for already extracted RGBA artwork."""

from PIL import Image, ImageChops, ImageFilter


def components(image, minimum=750):
    width, height = image.size
    data = bytearray(1 if a > 200 else 0 for a in image.getchannel('A').tobytes())
    found = []
    for index in range(len(data)):
        if not data[index]:
            continue
        data[index] = 0
        queue, pixels = [index], []
        left, top, right, bottom = width, height, 0, 0
        while queue:
            i = queue.pop()
            y, x = divmod(i, width)
            pixels.append(i)
            left, right = min(left, x), max(right, x)
            top, bottom = min(top, y), max(bottom, y)
            for j in (i-width if y else -1, i+width if y < height-1 else -1,
                      i-1 if x else -1, i+1 if x < width-1 else -1):
                if j >= 0 and data[j]:
                    data[j] = 0
                    queue.append(j)
        if len(pixels) >= minimum:
            found.append(((left, top, right+1, bottom+1), pixels))
    return found


def isolate(image, parts):
    mask = bytearray(image.width * image.height)
    for _, pixels in parts:
        for index in pixels:
            mask[index] = 255
    matte = Image.frombytes('L', image.size, bytes(mask)).filter(ImageFilter.MaxFilter(3))
    result = image.copy()
    result.putalpha(ImageChops.multiply(image.getchannel('A'), matte))
    result = result.crop(result.getbbox())
    output = Image.new('RGBA', (result.width+12, result.height+12))
    output.alpha_composite(result, (6, 6))
    return output
