#!/bin/bash

# Exit imediatamente se qualquer comando falhar
set -e

# 1. Gera o sufixo temporal no formato DDMMYYhhmm (Dia, Mês, Ano, Hora, Minuto)
TIMESTAMP=$(date +"%d%m%y%H%M")
ROM_NAME="capolei${TIMESTAMP}.smc"

echo "========================================"
echo "⚙️  Configurando e compilando OlhosCapolei [Build: $ROM_NAME]..."
echo "========================================"

cmake -S . -B build
cmake --build build -t clean
cmake --build build

echo "========================================"
echo "✅ Compilação concluída com sucesso!!!!"

# --- RELATÓRIO DE OCUPAÇÃO DE MEMÓRIA ---
if [ -f "build/mapa.txt" ]; then
    echo "📊 Resumo de Ocupação de Memória:"
    grep -A 12 "Segment list:" build/mapa.txt
fi
# ----------------------------------------

echo "========================================"

# Verifica se a ROM foi gerada antes de prosseguir
if [ ! -f "build/OlhosCapolei.smc" ]; then
    echo "❌ Erro: Arquivo build/OlhosCapolei.smc não foi encontrado."
    exit 1
fi

# =============================================================================
# 🌐 PIPELINE: DEPLOY DE ROM E ATUALIZAÇÃO DO SITE (VIA COMMIT @SITE@)
# =============================================================================
TARGET_SITE_DIR="Site/roms"
HTML_FILE="Site/index.html"

# Captura a mensagem do último commit local
LAST_COMMIT_MSG=$(git log -1 --pretty=%B 2>/dev/null || echo "")

if echo "$LAST_COMMIT_MSG" | grep -q "@SITE@"; then
    echo "🌐 Tag @SITE@ detectada no último commit! Atualizando site..."
    
    # 1. Copia a ROM com o nome capoleiDDMMYYhhmm.smc para Site/roms
    mkdir -p "$TARGET_SITE_DIR"
    echo "📦 Enviando $ROM_NAME para $TARGET_SITE_DIR..."
    cp build/OlhosCapolei.smc "$TARGET_SITE_DIR/$ROM_NAME"

    # 2. Atualiza o Site/index.html se ele existir
    if [ -f "$HTML_FILE" ]; then
        DATA_ATUAL=$(date +"%d-%m-%Y %H:%M")
        
        # Passa as variáveis para o Python manipular o HTML com precisão
        COMMIT_MSG="$LAST_COMMIT_MSG" ROM_FILE="$ROM_NAME" DATA_STR="$DATA_ATUAL" HTML_PATH="$HTML_FILE" python3 - << 'EOF'
import os
import re
import html

html_path = os.environ["HTML_PATH"]
commit_msg = os.environ["COMMIT_MSG"]
rom_file = os.environ["ROM_FILE"]
data_str = os.environ["DATA_STR"]

# Remove @SITE@ e limpa quebras de linha/espaços extras
clean_comment = commit_msg.replace("@SITE@", "").strip()
clean_comment = re.sub(r'\s+', ' ', clean_comment)
if not clean_comment:
    clean_comment = "Nova atualização"
clean_comment = html.escape(clean_comment)

with open(html_path, "r", encoding="utf-8") as f:
    content = f.read()

# Localiza o conteúdo dentro de <tbody>...</tbody>
tbody_match = re.search(r'(<tbody>)(.*?)(</tbody>)', content, flags=re.DOTALL | re.IGNORECASE)

if tbody_match:
    tbody_open = tbody_match.group(1)
    tbody_inner = tbody_match.group(2)
    tbody_close = tbody_match.group(3)
    
    # Conta quantas linhas (<tr>) já existem no tbody e soma 1
    current_rows = len(re.findall(r'<tr\b', tbody_inner, flags=re.IGNORECASE))
    next_thumb_num = current_rows + 1
    
    new_row = f"""
        <tr>
            <td>
                <img src="img/thumb{next_thumb_num}.jpeg" width="100px" height="100px" >
            </td>
            <td>
                {clean_comment}
            </td>
            <td>
                {data_str}
            </td>
            
            <td>
                <a href="play.html?rom={rom_file}">Play</a> 
            </td>
        </tr>"""
    
    # Insere a nova linha logo após a abertura de <tbody> (abaixo do cabeçalho)
    updated_tbody = tbody_open + new_row + tbody_inner + tbody_close
    new_content = content[:tbody_match.start()] + updated_tbody + content[tbody_match.end():]
    
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(new_content)
        
    print(f"✅ HTML atualizado! Nova linha adicionada (img/thumb{next_thumb_num}.jpeg | {rom_file}).")
else:
    print("⚠️  Aviso: Tag <tbody> não encontrada no index.html. O HTML não foi alterado.")
EOF
    else
        echo "⚠️  Arquivo $HTML_FILE não encontrado para atualização."
    fi
else
    echo "ℹ️  Tag @SITE@ não encontrada no último commit. Pulando atualização do site."
fi

# =============================================================================
# 💾 PIPELINE: DETECÇÃO AVANÇADA DE SD CARD (EVERDRIVE)
# =============================================================================
SD_PATH=$(findmnt -ln -o TARGET | grep -E '^/(media|run/media|mnt)/' | head -n 1 || true)

if [ -n "$SD_PATH" ]; then
    echo "💾 Dispositivo detectado em: $SD_PATH"
    
    echo "🔓 Remontando o cartão como Read-Write..."
    sudo mount -o remount,rw "$SD_PATH"
    
    echo "🧹 Limpando builds antigos do cartão..."
    rm -f "$SD_PATH"/OlhosCapolei* "$SD_PATH"/capolei*
    
    echo "🚀 Enviando $ROM_NAME para a raiz do cartão..."
    cp build/OlhosCapolei.smc "$SD_PATH/$ROM_NAME"
    
    # Força o Linux a descarregar o buffer de escrita no hardware físico
    sync
    echo "🎉 ROM $ROM_NAME atualizada com sucesso no seu Everdrive!"
else
    echo "⚠️  Não foi possível detectar o SD Card automaticamente."
fi

echo "========================================"

