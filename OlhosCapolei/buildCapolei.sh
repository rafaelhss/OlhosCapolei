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
# 🌐 PIPELINE: DEPLOY DE ROM, ATUALIZAÇÃO DO SITE E CAPTURA DE SCREENSHOT
# =============================================================================
TARGET_SITE_DIR="Site/roms"
SITE_IMG_DIR="Site/img"
HTML_FILE="Site/index.html"
SCREENSHOTS_DIR="/home/rafa/Pictures/Screenshots"

# Captura o hash curto e a mensagem do último commit local
LAST_COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "")
LAST_COMMIT_MSG=$(git log -1 --pretty=%B 2>/dev/null || echo "")

if echo "$LAST_COMMIT_MSG" | grep -q "@SITE@"; then
    # 1. Bloqueia execução repetida do exato mesmo commit
    if [ -f "$HTML_FILE" ] && [ -n "$LAST_COMMIT_HASH" ] && grep -q "<!-- commit:${LAST_COMMIT_HASH} -->" "$HTML_FILE"; then
        echo "⏭️  O commit [$LAST_COMMIT_HASH] já foi publicado na tabela do site. Pulando..."
    else
        echo "🌐 Tag @SITE@ detectada no commit [$LAST_COMMIT_HASH]! Atualizando site..."
        
        # Copia a nova ROM para Site/roms
        mkdir -p "$TARGET_SITE_DIR"
        echo "📦 Enviando $ROM_NAME para $TARGET_SITE_DIR..."
        cp build/OlhosCapolei.smc "$TARGET_SITE_DIR/$ROM_NAME"

        # Atualiza o Site/index.html e busca screenshot recente
        if [ -f "$HTML_FILE" ]; then
            DATA_ATUAL=$(date +"%d-%m-%Y %H:%M")
            
            COMMIT_HASH="$LAST_COMMIT_HASH" \
            COMMIT_MSG="$LAST_COMMIT_MSG" \
            ROM_FILE="$ROM_NAME" \
            DATA_STR="$DATA_ATUAL" \
            HTML_PATH="$HTML_FILE" \
            ROMS_DIR="$TARGET_SITE_DIR" \
            SITE_IMG_DIR="$SITE_IMG_DIR" \
            SCREENSHOTS_DIR="$SCREENSHOTS_DIR" \
            python3 - << 'EOF'
import os
import re
import html
import glob
import time
import shutil

html_path = os.environ["HTML_PATH"]
roms_dir = os.environ["ROMS_DIR"]
site_img_dir = os.environ["SITE_IMG_DIR"]
screenshots_dir = os.environ["SCREENSHOTS_DIR"]
commit_hash = os.environ["COMMIT_HASH"]
commit_msg = os.environ["COMMIT_MSG"]
rom_file = os.environ["ROM_FILE"]
data_str = os.environ["DATA_STR"]

# Remove @SITE@ e limpa quebras de linha/espaços extras
clean_comment = commit_msg.replace("@SITE@", "").strip()
clean_comment = re.sub(r'\s+', ' ', clean_comment)
if not clean_comment:
    clean_comment = "Nova atualização"
escaped_comment = html.escape(clean_comment)

with open(html_path, "r", encoding="utf-8") as f:
    content = f.read()

tbody_match = re.search(r'(<tbody>)(.*?)(</tbody>)', content, flags=re.DOTALL | re.IGNORECASE)

if tbody_match:
    tbody_open = tbody_match.group(1)
    tbody_inner = tbody_match.group(2)
    tbody_close = tbody_match.group(3)
    
    # Captura todos os blocos de linha (com comentário <!-- commit:... --> opcional + <tr>...</tr>)
    row_pattern = re.compile(r'(\s*(?:<!--\s*commit:[^\s>]+\s*-->\s*)?<tr>.*?</tr>)', flags=re.DOTALL | re.IGNORECASE)
    rows = row_pattern.findall(tbody_inner)
    
    replaced = False
    new_rows = []
    target_thumb_filename = None
    
    for row in rows:
        tds = re.findall(r'<td[^>]*>(.*?)</td>', row, flags=re.DOTALL | re.IGNORECASE)
        if len(tds) >= 4:
            # Extrai o texto puro da coluna de comentário (2ª coluna)
            row_comment = html.unescape(re.sub(r'<[^>]+>', '', tds)).strip()
            row_comment = re.sub(r'\s+', ' ', row_comment)
            
            # Se o comentário for idêntico (ignorando maiúsculas/minúsculas), substitui o registro
            if not replaced and row_comment.lower() == clean_comment.lower():
                img_match = re.search(r'src=["\']([^"\']+)["\']', tds, flags=re.IGNORECASE)
                if img_match:
                    # Extrai apenas o nome base (ex: thumb2) e força extensão .png
                    base_name = os.path.splitext(os.path.basename(img_match.group(1)))[0]
                    target_thumb_filename = f"{base_name}.png"
                else:
                    target_thumb_filename = f"thumb{len(rows)}.png"
                
                img_src = f"img/{target_thumb_filename}"
                
                # Apaga a ROM antiga da pasta Site/roms para não sobrar lixo
                old_rom_match = re.search(r'\?rom=([^"\'>\s]+)', tds, flags=re.IGNORECASE)
                if old_rom_match:
                    old_rom_path = os.path.join(roms_dir, old_rom_match.group(1))
                    if os.path.exists(old_rom_path) and old_rom_match.group(1) != rom_file:
                        try:
                            os.remove(old_rom_path)
                            print(f"🧹 ROM antiga removida do site: {old_rom_match.group(1)}")
                        except OSError:
                            pass

                updated_row = f"""
        <!-- commit:{commit_hash} -->
        <tr>
            <td>
                <img src="{img_src}" width="100px" height="100px" >
            </td>
            <td>
                {escaped_comment}
            </td>
            <td>
                {data_str}
            </td>
            
            <td>
                <a href="play.html?rom={rom_file}">Play</a> 
            </td>
        </tr>"""
                new_rows.append(updated_row)
                replaced = True
                print(f"🔄 Comentário '{clean_comment}' já existia! Registro atualizado ({img_src} | {rom_file}).")
            else:
                new_rows.append(row)
        else:
            new_rows.append(row)
            
    if replaced:
        updated_tbody_inner = "".join(new_rows)
        if not updated_tbody_inner.endswith("\n        "):
            updated_tbody_inner += "\n        "
        updated_tbody = tbody_open + updated_tbody_inner + tbody_close
    else:
        # Se for um comentário novo, cria nova linha no topo
        next_thumb_num = len(rows) + 1
        target_thumb_filename = f"thumb{next_thumb_num}.png"
        new_row = f"""
        <!-- commit:{commit_hash} -->
        <tr>
            <td>
                <img src="img/{target_thumb_filename}" width="100px" height="100px" >
            </td>
            <td>
                {escaped_comment}
            </td>
            <td>
                {data_str}
            </td>
            
            <td>
                <a href="play.html?rom={rom_file}">Play</a> 
            </td>
        </tr>"""
        updated_tbody = tbody_open + new_row + tbody_inner + tbody_close
        print(f"✅ HTML atualizado! Nova linha adicionada (img/{target_thumb_filename} | {rom_file}).")
        
    new_content = content[:tbody_match.start()] + updated_tbody + content[tbody_match.end():]
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(new_content)

    # =========================================================================
    # 📸 BUSCA SCREENSHOT RECENTE (ATÉ 5 MINUTOS) EM /home/rafa/Pictures/Screenshots
    # =========================================================================
    if target_thumb_filename and os.path.isdir(screenshots_dir):
        now = time.time()
        five_minutes_ago = now - (5 * 60)
        recent_pngs = []
        
        for file_path in glob.glob(os.path.join(screenshots_dir, "*.png")):
            if os.path.isfile(file_path):
                mtime = os.path.getmtime(file_path)
                if mtime >= five_minutes_ago:
                    recent_pngs.append((mtime, file_path))
                    
        if recent_pngs:
            # Ordena pela data de modificação mais recente e pega o primeiro
            recent_pngs.sort(key=lambda x: x[0], reverse=True)
            newest_screenshot = recent_pngs[0][1]
            
            os.makedirs(site_img_dir, exist_ok=True)
            dest_path = os.path.join(site_img_dir, target_thumb_filename)
            shutil.copy2(newest_screenshot, dest_path)
            print(f"📸 Screenshot '{os.path.basename(newest_screenshot)}' copiado para '{dest_path}'!")
        else:
            print(f"⚠️  Nenhum screenshot .png dos últimos 5 minutos encontrado em {screenshots_dir}.")
            print(f"👉 Lembre-se de salvar manualmente em: {os.path.join(site_img_dir, target_thumb_filename)}")
else:
    print("⚠️  Aviso: Tag <tbody> não encontrada no index.html. O HTML não foi alterado.")
EOF
        else
            echo "⚠️  Arquivo $HTML_FILE não encontrado para atualização."
        fi
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
