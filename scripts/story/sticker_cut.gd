class_name StickerCut
extends RefCounted
## 스티커 그림 읽기 + 배경 오려 내기 마스크.
## art/characters/*.png는 아직 크림색 종이 배경이 붙은 RGB라, 네 귀퉁이에서 배경색으로 이어진 칸만
## 작은 해상도로 채워 투명 마스크를 만든다 (흰 다이컷 테두리에서 멈춤). 투명 배경 PNG가 오면 그대로 씀.
## 임포트 안 된 PNG도 읽는다 (Image.load_from_file).

const MASK_W := 240  # 마스크 가로 칸 수. 테두리가 3칸쯤 남는 크기
const TOL := 9  # 배경색과 채널마다 이만큼까지 같다고 봄 (배경 237~245, 흰 테두리 253~255)

static var _cache := {}  # path -> {tex, mask}


## {tex: Texture2D, mask: Texture2D}, 못 읽으면 {}
static func load_sticker(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	if _cache.has(path):
		return _cache[path]
	var img := _image(path)
	if img == null:
		_cache[path] = {}
		return {}
	var out := {tex = ImageTexture.create_from_image(img), mask = _mask(img)}
	_cache[path] = out
	return out


static func _image(path: String) -> Image:
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		if t:
			return t.get_image()
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return img if img and not img.is_empty() else null


static func _mask(src: Image) -> Texture2D:
	var img: Image = src.duplicate()
	if img.is_compressed():
		img.decompress()
	var w := MASK_W
	var h := maxi(1, roundi(w * img.get_height() / float(img.get_width())))
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGBA8)
	var px := img.get_data()
	var out := PackedByteArray()
	out.resize(w * h)
	out.fill(255)
	# 이미 투명 배경이면 알파를 그대로 마스크로
	if px[3] < 128 and px[(w * h - 1) * 4 + 3] < 128:
		for i in w * h:
			out[i] = px[i * 4 + 3]
		return ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_L8, out))
	var corners := [0, w - 1, (h - 1) * w, w * h - 1]
	var bg := [0, 0, 0]
	for i in corners:
		for ch in 3:
			bg[ch] += px[i * 4 + ch] / 4.0
	var stack := PackedInt32Array(corners)
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if out[i] == 0:
			continue
		var o := i * 4
		if absf(px[o] - bg[0]) > TOL or absf(px[o + 1] - bg[1]) > TOL or absf(px[o + 2] - bg[2]) > TOL:
			continue
		out[i] = 0
		var x := i % w
		if x > 0:
			stack.append(i - 1)
		if x < w - 1:
			stack.append(i + 1)
		if i >= w:
			stack.append(i - w)
		if i < (h - 1) * w:
			stack.append(i + w)
	return ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_L8, out))
