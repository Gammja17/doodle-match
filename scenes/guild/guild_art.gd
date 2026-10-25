extends RefCounted
## (class_name 없음: 쓰는 쪽에서 const GUILD_ART := preload("res://scenes/guild/guild_art.gd"))
## 가구 그림 읽기 (한 번 읽으면 기억). 투명 여백을 잘라 내고 게임 크기로 줄임 → 그림 맨 아래 = 가구 발밑.
## 고도에 들여온(.import) 그림이면 그대로 읽고, 아직이면 PNG 파일을 바로 읽음 (UI 아트 후보를 임시로 쓰는 동안. 내보낸 게임엔 들여온 그림이 있어야 함).

const MAX_PX := 320  # 줄인 그림의 긴 변 (방 680px에서 가구는 많아야 200px쯤)

static var _cache := {}  # 경로 -> Texture2D (못 읽으면 null)
static var _masks := {}  # 경로 -> BitMap (불투명한 곳 = 누를 수 있는 곳)


## 그림의 불투명한 곳 (texture()를 먼저 부른 그림만)
static func mask(path: String) -> BitMap:
	return _masks.get(path)


## 그림이 없거나 못 읽으면 null
static func texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path]
	var img: Image
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		img = t.get_image() if t else null
	elif FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	var tex: Texture2D = null
	if img and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		img = img.get_region(img.get_used_rect())
		var s := float(MAX_PX) / maxf(img.get_width(), img.get_height())
		if s < 1.0:
			img.resize(maxi(1, roundi(img.get_width() * s)), maxi(1, roundi(img.get_height() * s)), Image.INTERPOLATE_LANCZOS)
		tex = ImageTexture.create_from_image(img)
		var bm := BitMap.new()
		bm.create_from_image_alpha(img, 0.3)
		_masks[path] = bm
	_cache[path] = tex
	return tex
