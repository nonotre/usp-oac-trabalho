#!/bin/bash
# Compila uma copia do simulador do professor com escala ajustavel.
#   - ICMC_ESCALA=N (padrao 2, como o original): cada ponto vira N x N pixels
#   - a area de desenho fica com o tamanho exato da tela (320N x 240N), sem a
#     tarja preta de 7 pixels que o original deixa embaixo (645 x 487)
#   - a largura minima da janela acompanha a escala (o original fixa 1024, e
#     o gerenciador de janelas pode cortar o resto)
# O processador nao muda: so o desenho da janela. Saida: ../material/bin/sim-escala
set -e
cd "$(dirname "$0")/.."
ORIG=../material/Processador-ICMC/Simulator_Source
DEST=../material/sim-escala
rm -rf "$DEST" && cp -r "$ORIG" "$DEST"
python3 - "$DEST/View.cpp" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
def rep(a, b):
    global s
    assert a in s, a
    s = s.replace(a, b)
rep('#include "View.h"', '#include "View.h"\n#include <cstdlib>\n'
    'static int escala() { static int e = 0; if (!e) { const char *v = getenv("ICMC_ESCALA");'
    ' e = v ? atoi(v) : 2; if (e < 1) e = 1; } return e; }')
rep('gtk_widget_queue_draw_area(outputarea, 16*(pos%40), 16*(pos/40), 16, 16);',
    'gtk_widget_queue_draw_area(outputarea, 8*escala()*(pos%40), 8*escala()*(pos/40), 8*escala(), 8*escala());')
rep('gtk_widget_set_size_request(outputarea , 645, 487);',
    'gtk_widget_set_size_request(outputarea , 320*escala(), 240*escala());')
rep('gtk_widget_set_size_request(window, 1024, -1);',
    'gtk_widget_set_size_request(window, 320*escala() + 374 + 40 > 1024 ? 320*escala() + 374 + 40 : 1024, -1);')
rep('gtk_widget_set_size_request(textview, 374, 487);',
    'gtk_widget_set_size_request(textview, 374, 240*escala());')
rep('vi->_draw_pixmap(cr, vi->block[i].sym, 16*(i%40), 16*(i/40), 2, vi->block[i].color);',
    'vi->_draw_pixmap(cr, vi->block[i].sym, 8*escala()*(i%40), 8*escala()*(i/40), escala(), vi->block[i].color);')
open(p, 'w').write(s)
PY
export PKG_CONFIG_PATH=$HOME/.local/opt/gtk2/lib/pkgconfig
cd "$DEST"
g++ main.cpp View.cpp Controller.cpp Sound.cpp Model.cpp -O3 -march=native -o ../bin/sim-escala \
  $(pkg-config --libs --cflags gtk+-2.0) -pthread -lgthread-2.0 -lSDL2 -Wl,-rpath,$HOME/.local/opt/gtk2/lib 2>&1 | grep -E " error" || true
ls -la ../bin/sim-escala
