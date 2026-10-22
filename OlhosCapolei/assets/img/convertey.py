import sys
import os

def converter_yychr_para_snes(arquivo_entrada, arquivo_saida):
    """
    Lê uma paleta de 768 bytes do YY-CHR (RGB888) e exporta
    um binário puro de 32 bytes (16 cores BGR555 Little Endian) para o SNES.
    """
    if not os.path.exists(arquivo_entrada):
        print(f"Erro: O arquivo '{arquivo_entrada}' não foi encontrado.")
        return

    with open(arquivo_entrada, "rb") as f:
        dados_yychr = f.read()

    # Garante que o arquivo do YY-CHR tem pelo menos o tamanho esperado
    if len(dados_yychr) < 768:
        print("Aviso: O arquivo de entrada é menor que 768 bytes. Convertendo o que for possível.")

    bytes_snes = bytearray()
    
    # Processa apenas as primeiras 16 cores (16 * 3 bytes = 48 bytes lidos)
    for i in range(16):
        offset = i * 3
        if offset + 2 < len(dados_yychr):
            r8 = dados_yychr[offset]
            g8 = dados_yychr[offset+1]
            b8 = dados_yychr[offset+2]
        else:
            r8, g8, b8 = 0, 0, 0 # Fallback caso o arquivo termine mais cedo

        # Converte a escala de 8 bits (0-255) para 5 bits do SNES (0-31)
        r5 = r8 >> 3
        g5 = g8 >> 3
        b5 = b8 >> 3

        # Empacota no formato de hardware BGR555 do SNES: 0BBBBBGGGGGRRRRR
        palavra_16bits = (b5 << 10) | (g5 << 5) | r5

        # SNES usa Little Endian (Byte baixo primeiro, depois o byte alto)
        bytes_snes.append(palavra_16bits & 0xFF)          # Low Byte
        bytes_snes.append((palavra_16bits >> 8) & 0xFF)   # High Byte

    # Grava o binário puro pronto de exatamente 32 bytes
    with open(arquivo_saida, "wb") as f:
        f.write(bytes_snes)

    print(f"Sucesso! '{arquivo_entrada}' convertido para '{arquivo_saida}' (32 bytes puros).")

if __name__ == "__main__":
    # Configuração dos arquivos (mude os nomes se necessário)
    PALETA_YYCHR = "Sprites10.pal"  # O arquivo de 768 bytes que você salva no YY-CHR
    PALETA_SNES  = "Sprites10.pal"      # O arquivo de 32 bytes que seu Assets.s vai ler

    converter_yychr_para_snes(PALETA_YYCHR, PALETA_SNES)

