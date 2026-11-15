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
        ROM_UPDATED_FLAG="/tmp/capolei_rom_updated.flag" \
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
flag_path = os.environ["ROM_UPDATED_FLAG"]

if os.path.exists(flag_path):
    os.remove(flag_path)

def try_copy_recent_screenshot(target_filename, is_retry=False):
    dest_path = os.path.join(site_img_dir, target_filename)
    if not os.path.isdir(screenshots_dir):
        print(f"⚠️  Pasta de screenshots não encontrada: {screenshots_dir}")
        return False

    now = time.time()
    five_minutes_ago = now - (5 * 60)
    all_pngs = []
    recent_pngs = []

    for file_path in glob.glob(os.path.join(screenshots_dir, "*.png")):
        if os.path.isfile(file_path):
            mtime = os.path.getmtime(file_path)
            all_pngs.append((mtime, file_path))
            if mtime >= five_minutes_ago:
                recent_pngs.append((mtime, file_path))

    if recent_pngs:
        recent_pngs.sort(key=lambda item: item[0], reverse=True)
        newest_screenshot = recent_pngs[0][1]
        os.makedirs(site_img_dir, exist_ok=True)
        shutil.copy2(newest_screenshot, dest_path)
        print(f"📸 Screenshot '{os.path.basename(newest_screenshot)}' copiado para '{dest_path}'!")
        return True
    else:
        if not is_retry or not os.path.exists(dest_path):
            print(f"⚠️  Nenhum screenshot .png dos últimos 5 minutos encontrado em {screenshots_dir}.")
            if all_pngs:
                all_pngs.sort(key=lambda item: item[0], reverse=True)
                mins_ago = int((now - all_pngs[0][0]) / 60)
                print(f"ℹ️  O print mais recente lá dentro ('{os.path.basename(all_pngs[0][1])}') foi tirado há {mins_ago} minutos.")
            print(f"👉 Tire o print agora e rode ./buildCapolei.sh novamente para salvar em '{dest_path}'.")
        return False

with open(html_path, "r", encoding="utf-8") as f:
    content = f.read()

tbody_match = re.search(r'(<tbody>)(.*?)(</tbody>)', content, flags=re.DOTALL | re.IGNORECASE)

if not tbody_match:
    print("⚠️  Aviso: Tag <tbody> não encontrada no index.html. O HTML não foi alterado.")
    exit(0)

tbody_open = tbody_match.group(1)
tbody_inner = tbody_match.group(2)
tbody_close = tbody_match.group(3)

row_pattern = re.compile(r'(\s*(?:<!--\s*commit:[^\s>]+\s*-->\s*)?<tr>.*?</tr>)', flags=re.DOTALL | re.IGNORECASE)
rows = row_pattern.findall(tbody_inner)

# =========================================================================
# CASO 1: O COMMIT JÁ ESTÁ NA TABELA -> VERIFICA SE FALTA COPIAR A IMAGEM
# =========================================================================
existing_commit_row = None
for row in rows:
    if commit_hash and f"<!-- commit:{commit_hash} -->" in row:
        existing_commit_row = row
        break

if existing_commit_row:
    img_match = re.search(r'src=["\']([^"\']+)["\']', existing_commit_row, flags=re.IGNORECASE)
    if img_match:
        target_thumb_filename = os.path.basename(img_match.group(1))
        dest_img_path = os.path.join(site_img_dir, target_thumb_filename)
        if not os.path.exists(dest_img_path):
            print(f"🔍 Commit [{commit_hash}] já publicado, mas '{dest_img_path}' ainda não existe. Buscando print...")
            try_copy_recent_screenshot(target_thumb_filename, is_retry=True)
        else:
            print(f"⏭️  Commit [{commit_hash}] já publicado e imagem '{dest_img_path}' já está na pasta. Pulando...")
    else:
        print(f"⏭️  O commit [{commit_hash}] já foi publicado na tabela do site. Pulando...")
    exit(0)

# =========================================================================
# CASO 2: NOVO COMMIT -> ATUALIZA OU INSERE NO HTML E COPIA A ROM
# =========================================================================
clean_comment = commit_msg.replace("@SITE@", "").strip()
clean_comment = re.sub(r'\s+', ' ', clean_comment)
if not clean_comment:
    clean_comment = "Nova atualização"
escaped_comment = html.escape(clean_comment)

replaced = False
new_rows = []
target_thumb_filename = None

for row in rows:
    tds = re.findall(r'<td[^>]*>(.*?)</td>', row, flags=re.DOTALL | re.IGNORECASE)
    if len(tds) >= 4:
        col_comment_html = tds[1]
        row_comment = html.unescape(re.sub(r'<[^>]+>', '', col_comment_html)).strip()
        row_comment = re.sub(r'\s+', ' ', row_comment)
        
        if not replaced and row_comment.lower() == clean_comment.lower():
            col_img_html = tds[0]
            img_match = re.search(r'src=["\']([^"\']+)["\']', col_img_html, flags=re.IGNORECASE)
            if img_match:
                base_name, _ = os.path.splitext(os.path.basename(img_match.group(1)))
                target_thumb_filename = f"{base_name}.png"
            else:
                target_thumb_filename = f"thumb{len(rows)}.png"
            
            img_src = f"img/{target_thumb_filename}"
            
            # Remove a imagem antiga se existir para garantir que uma nova captura seja vinculada
            old_dest_img = os.path.join(site_img_dir, target_thumb_filename)
            if os.path.exists(old_dest_img):
                try:
                    os.remove(old_dest_img)
                except OSError:
                    pass

            col_link_html = tds[3]
            old_rom_match = re.search(r'\?rom=([^"\'>\s]+)', col_link_html, flags=re.IGNORECASE)
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

# Sinaliza ao bash para copiar a nova ROM para Site/roms
with open(flag_path, "w") as f:
    f.write("1")

if target_thumb_filename:
    try_copy_recent_screenshot(target_thumb_filename, is_retry=False)
EOF

        # Copia a ROM apenas se houve nova inclusão ou atualização no HTML
        if [ -f "/tmp/capolei_rom_updated.flag" ]; then
            mkdir -p "$TARGET_SITE_DIR"
            echo "📦 Enviando $ROM_NAME para $TARGET_SITE_DIR..."
            cp build/OlhosCapolei.smc "$TARGET_SITE_DIR/$ROM_NAME"
            rm -f "/tmp/capolei_rom_updated.flag"
        fi
    else
        echo "⚠️  Arquivo $HTML_FILE não encontrado para atualização."
    fi
else
    echo "ℹ️  Tag @SITE@ não encontrada no último commit. Pulando atualização do site."
fi

# =============================================================================
# 💾 PIPELINE: DETECÇÃO AVANÇADA DE SD CARD (EVERDRIVE) E EJECT SEGURO
# =============================================================================
SD_PATH=$(findmnt -ln -o TARGET | grep -E '^/(media|run/media|mnt)/' | head -n 1 || true)

if [ -n "$SD_PATH" ]; then
    SD_DEV=$(findmnt -n -o SOURCE "$SD_PATH" || true)
    echo "💾 Dispositivo detectado em: $SD_PATH ($SD_DEV)"
    
    echo "🔓 Remontando o cartão como Read-Write..."
    sudo mount -o remount,rw "$SD_PATH"
    
    echo "🧹 Limpando builds antigos do cartão..."
    rm -f "$SD_PATH"/OlhosCapolei* "$SD_PATH"/capolei*
    
    echo "🚀 Enviando $ROM_NAME para a raiz do cartão..."
    cp build/OlhosCapolei.smc "$SD_PATH/$ROM_NAME"
    
    # Força o Linux a descarregar o buffer de escrita no hardware físico
    sync
    echo "🎉 ROM $ROM_NAME atualizada com sucesso no seu Everdrive!"

    # Eject seguro via udisksctl
    if [ -n "$SD_DEV" ] && command -v udisksctl >/dev/null 2>&1; then
        echo "⏏️  Ejetando o SD Card com segurança..."
        udisksctl unmount -b "$SD_DEV" --no-user-interaction
        
        PARENT_DEV=$(lsblk -no PKNAME "$SD_DEV" 2>/dev/null | head -n 1 || true)
        if [ -n "$PARENT_DEV" ]; then
            udisksctl power-off -b "/dev/$PARENT_DEV" --no-user-interaction 2>/dev/null || true
        fi
        echo "✅ Pode puxar o cartão SD com segurança!"
    else
        sudo umount "$SD_PATH"
        echo "✅ Cartão desmontado com segurança!"
    fi
else
    echo "⚠️  Não foi possível detectar o SD Card automaticamente."
fi

echo "========================================"
