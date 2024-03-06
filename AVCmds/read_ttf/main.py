from fontTools.ttLib import TTFont


font = TTFont("C:\\Program Files (x86)\\Steam\\steamapps\\common\\Stormworks\\rom\\graphics\\fonts\\noto.ttf")
cmap = font['cmap'].getcmap(3,1).cmap
glyphs = font.getGlyphSet()

char_range = (32, 128)

parts = []
for i in range(*char_range):
	char = chr(i)
	if i in cmap and cmap[i] in glyphs:
		char_width = glyphs[cmap[i]].width
		parts.append(f"[{repr(char)}]={glyphs[cmap[i]].width}")

print(f"{{{','.join(parts)}}}")
print()
print(f"Default width: {glyphs['.notdef'].width}")
