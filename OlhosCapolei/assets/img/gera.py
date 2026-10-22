import struct

# Insira aqui a lista com as suas 16 cores no formato (R, G, B) de 0 a 255
# Lembre-se: a primeira cor da lista sempre sera a transparente no SNES
cores_rgb = [
    (100, 100, 100),         # Cor 00: Transparente (Preto)
    (255, 255, 255), # Cor 01: Branco
    (255, 100, 200),     # Cor 02: Vermelho
    (0, 0, 255),     # Cor 03: Azul
    (0, 255, 0),     # Cor 04: Verde
    (255, 255, 0),   # Cor 05: Amarelo
    (255, 0, 255),   # Cor 06: Roxo
    (0, 255, 255),   # Cor 07: Ciano
    (128, 128, 128), # Cor 08: Cinza
    (255, 128, 0),   # Cor 09: Laranja
    (128, 0, 0),     # Cor 10: Marrom escuro
    (0, 128, 0),     # Cor 11: Verde escuro
    (0, 0, 128),     # Cor 12: Azul escuro
    (128, 0, 128),   # Cor 13: Roxo escuro
    (64, 64, 64),    # Cor 14: Cinza escuro
    (200, 200, 200)  # Cor 15: Cinza claro
]

bytes_finais = bytearray()

for r, g, b in cores_rgb:
    # Converte de 8-bits (0-255) para os 5-bits (0-31) do hardware do SNES
    r5 = r >> 3
    g5 = g >> 3
    b5 = b >> 3
    
    # Monta a estrutura de bits BGR555 do SNES: 0BBBBBGGGGGRRRRR
    snes_color = (b5 << 10) | (g5 << 5) | r5
    
    # Empacota no formato binario Little-Endian de 16-bits (2 bytes por cor)
    bytes_finais.extend(struct.pack('<H', snes_color))

# Salva o arquivo final de exatamente 32 bytes para o seu Assets.s
with open("Sprites9.pal", "wb") as f:
    f.write(bytes_finais)

print("Arquivo Sprites7.pal gerado com sucesso!")
print("Tamanho do arquivo: " + str(len(bytes_finais)) + " bytes.")

