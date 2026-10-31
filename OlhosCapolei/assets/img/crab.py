from PIL import Image

# 1. Cria a tela nativa no tamanho exato de 64x32
width = 64
height = 32
# Usando o fundo preto absoluto idêntico ao da imagem de referência
img = Image.new('RGB', (width, height), (0, 0, 0))
pixels = img.load()

# Paleta de Cores extraída da sua imagem de referência (Estilo SNES de 16 cores)
C_SOMBRA   = (115, 12, 6)   # Vermelho escuro/sombra
C_BASE     = (185, 22, 10)  # Vermelho médio base do corpo
C_VIVO     = (235, 65, 15)  # Vermelho claro vivo
C_BRILHO   = (255, 135, 30) # Laranja para os realces de luz do casco

# --- 2. Casco Central Achatado e Largo (Mapeamento de Blocos) ---
for y in range(6, 20):
    for x in range(16, 48):
        # Gradiente horizontal para simular a iluminação da imagem
        if y in [6, 19]:
            if 22 <= x <= 42: pixels[x, y] = C_SOMBRA
        elif y in [7, 18]:
            if 19 <= x <= 45: pixels[x, y] = C_BASE
        elif y in [8, 17]:
            if 17 <= x <= 47: pixels[x, y] = C_VIVO
        else:
            # Miolo do casco com realce brilhante na parte superior
            if 8 <= y <= 12 and 24 <= x <= 40:
                pixels[x, y] = C_BRILHO
            elif y <= 14:
                pixels[x, y] = C_VIVO
            else:
                pixels[x, y] = C_BASE

# --- 3. Grandes Garras Frontais (Viradas para baixo e para dentro) ---
# Garra Esquerda
for y in range(17, 30):
    for x in range(18, 31):
        if y - 17 >= x - 18:  # Curvatura interna da garra
            # Recorte simples para simular pinça aberta na ponta de baixo
            if y > 25 and 25 <= x <= 27: continue
            pixels[x, y] = C_VIVO if y < 23 else C_BASE

# Garra Direita
for y in range(17, 30):
    for x in range(33, 46):
        if y - 17 >= 45 - x:  # Curvatura espelhada
            if y > 25 and 36 <= x <= 38: continue
            pixels[x, y] = C_VIVO if y < 23 else C_BASE

# --- 4. Pernas Laterais Longas (Esticando-se até os cantos 0 e 63) ---
for i in range(18):
    # Pernas Esquerdas (Ocupando a lateral esquerda até a borda)
    if 16 - i >= 0:
        pixels[16 - i, 8 - i // 3] = C_VIVO if i < 8 else C_BASE   # Perna Superior 1
        pixels[16 - i, 11 - i // 4] = C_VIVO if i < 10 else C_BASE # Perna 2
        pixels[16 - i, 14 + i // 5] = C_BASE                       # Perna 3
        pixels[16 - i, 18 + i // 3] = C_SOMBRA                     # Perna Inferior 4

    # Pernas Direitas (Ocupando a lateral direita até a borda)
    if 47 + i < 64:
        pixels[47 + i, 8 - i // 3] = C_VIVO if i < 8 else C_BASE
        pixels[47 + i, 11 - i // 4] = C_VIVO if i < 10 else C_BASE
        pixels[47 + i, 14 + i // 5] = C_BASE
        pixels[47 + i, 18 + i // 3] = C_SOMBRA

# 5. Salva o arquivo final puro (.png indexado perfeitamente em 64x32)
img.save('caranguejo_snes_64x32.png')
print("Sucesso! Imagem 'caranguejo_snes_64x32.png' gerada usando a referência.")

