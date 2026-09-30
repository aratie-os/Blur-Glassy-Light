# Blur-Glassy Light e Dark para Plasma 6

Base Plasma 6-only dos temas Blur-Glassy Light e Blur-Glassy Dark.

Este fork deriva do projeto original de l4k1:

- https://github.com/L4ki/Blur-Glassy
- https://www.pling.com/p/1267335

O objetivo desta base e manter a aparencia Light original do Blur-Glassy e oferecer uma variante Dark coerente, preservando glass, blur e transparencia. Este fork nao e oficial.

## Alvo

- Kubuntu 26.04 LTS
- KDE Plasma 6.6
- KDE Frameworks 6
- Qt 6
- Wayland como sessao principal

## Componentes

- `Blur-Glassy/`: Plasma Style Light canonico.
- `Blur-Glassy-Dark/`: Plasma Style Dark autocontido.
- `Color Schemes/BlurGlassyDark.colors`: Color Scheme Dark usado pelo Global Theme Dark.
- `Global Themes/Blur-Glassy-Light-Global-6/`: Global Theme Light Plasma 6.
- `Global Themes/Blur-Glassy-Dark-Global-6/`: Global Theme Dark Plasma 6.
- `Windows Decorations For Plasma 6/Blur-Glassy-Solid-Aurorae-6/`: decoracao Aurorae usada pelo Global Theme.
- `Windows Decorations For Plasma 6/Blur-Glassy-Aurorae-6/`: decoracao Aurorae complementar.
- `Windows Decorations For Plasma 6/Blur-Glassy-Dark-Aurorae-6/`: decoracao Aurorae do Global Theme Dark.
- `tools/audit-theme.sh`: auditoria local de metadados, SVGs e referencias principais.

## Estrategia da variante Dark

O Plasma Style Dark e autocontido. Embora o formato de temas documente `FallbackTheme`, os testes com KF6Svg 6.24 no Plasma 6.6 nao resolveram um fallback customizado para `Blur-Glassy`; o resultado usava assets do tema padrao. Manter todos os assets no pacote Dark garante instalacao independente e evita uma aparencia hibrida com Breeze.

Os assets compartilhados foram preservados byte a byte sempre que funcionavam com a paleta Dark. Somente backgrounds e tooltips que continham superficies Light visiveis possuem variantes especificas.

## Dependencias externas do Global Theme

O Global Theme Light aponta para componentes externos publicados no KDE Store quando instalado via KNewStuff:

- Blur-Glassy color scheme: `kns://colorschemes.knsrc/api.kde-look.org/1306011`
- Breeze-Noir-Black-Blue icons: `kns://icons.knsrc/api.kde-look.org/1361471`
- Win-Light-Wallpaper: `kns://wallpaper.knsrc/api.kde-look.org/1994278`

O Plasma Style `Blur-Glassy` e as decoracoes Aurorae sao mantidos neste repositorio e devem ser instalados junto com o Global Theme. As dependencias KNewStuff desses componentes upstream nao sao usadas aqui porque os pacotes remotos atuais podem baixar variantes historicas ou incompletas para validacao local no Plasma 6.

Para instalacao manual a partir deste repositorio, instale tambem o color scheme, icones e wallpaper se quiser reproduzir exatamente o Global Theme completo.

O Global Theme Dark nao possui dependencias KNewStuff. Ele usa os componentes locais `Blur-Glassy-Dark`, `BlurGlassyDark` e `Blur-Glassy-Dark-Aurorae-6`, alem de `breeze-dark` e `breeze_cursors`, fornecidos pelo Plasma. Ele preserva o wallpaper atual do usuario.

## Instalacao local

Os comandos abaixo instalam somente no usuario atual:

```bash
mkdir -p ~/.local/share/plasma/desktoptheme
cp -a Blur-Glassy ~/.local/share/plasma/desktoptheme/
cp -a Blur-Glassy-Dark ~/.local/share/plasma/desktoptheme/

mkdir -p ~/.local/share/color-schemes
cp -a "Color Schemes/BlurGlassyDark.colors" ~/.local/share/color-schemes/

mkdir -p ~/.local/share/plasma/look-and-feel
cp -a "Global Themes/Blur-Glassy-Light-Global-6" ~/.local/share/plasma/look-and-feel/
cp -a "Global Themes/Blur-Glassy-Dark-Global-6" ~/.local/share/plasma/look-and-feel/

mkdir -p ~/.local/share/aurorae/themes
cp -a "Windows Decorations For Plasma 6/Blur-Glassy-Solid-Aurorae-6" ~/.local/share/aurorae/themes/
cp -a "Windows Decorations For Plasma 6/Blur-Glassy-Aurorae-6" ~/.local/share/aurorae/themes/
cp -a "Windows Decorations For Plasma 6/Blur-Glassy-Dark-Aurorae-6" ~/.local/share/aurorae/themes/
```

Aplicacao dos Plasma Styles:

```bash
plasma-apply-desktoptheme Blur-Glassy
plasma-apply-desktoptheme Blur-Glassy-Dark
```

Aplicacao dos Global Themes:

```bash
plasma-apply-lookandfeel --apply Blur-Glassy-Light-Global-6
plasma-apply-lookandfeel --apply Blur-Glassy-Dark-Global-6
```

## Desinstalacao local

```bash
rm -rf ~/.local/share/plasma/desktoptheme/Blur-Glassy
rm -rf ~/.local/share/plasma/desktoptheme/Blur-Glassy-Dark
rm -f ~/.local/share/color-schemes/BlurGlassyDark.colors
rm -rf ~/.local/share/plasma/look-and-feel/Blur-Glassy-Light-Global-6
rm -rf ~/.local/share/plasma/look-and-feel/Blur-Glassy-Dark-Global-6
rm -rf ~/.local/share/aurorae/themes/Blur-Glassy-Solid-Aurorae-6
rm -rf ~/.local/share/aurorae/themes/Blur-Glassy-Aurorae-6
rm -rf ~/.local/share/aurorae/themes/Blur-Glassy-Dark-Aurorae-6
```

## Validacao

```bash
tools/audit-theme.sh
kpackagetool6 --type Plasma/Theme --show Blur-Glassy --packageroot "$PWD"
kpackagetool6 --type Plasma/Theme --show Blur-Glassy-Dark --packageroot "$PWD"
kpackagetool6 --type Plasma/LookAndFeel --show Blur-Glassy-Light-Global-6 --packageroot "$PWD/Global Themes"
kpackagetool6 --type Plasma/LookAndFeel --show Blur-Glassy-Dark-Global-6 --packageroot "$PWD/Global Themes"
kpackagetool6 --type KWin/Aurorae --show Blur-Glassy-Solid-Aurorae-6 --packageroot "$PWD/Windows Decorations For Plasma 6"
kpackagetool6 --type KWin/Aurorae --show Blur-Glassy-Dark-Aurorae-6 --packageroot "$PWD/Windows Decorations For Plasma 6"
```

## Notas de Plasma 6

Os Plasma Styles usam `metadata.json` e `plasmarc`. As configuracoes de transparencia adaptativa e blur ficam em `plasmarc` e sao iguais nas variantes Light e Dark.

O campo `"X-Plasma-API": "5.0"` permanece no `metadata.json` do Plasma Style porque ele ainda e usado pelo formato atual de Plasma Styles, inclusive nos temas Breeze do Plasma 6; aqui ele nao indica suporte a Plasma 5.

## Upstream Git

Se o remote `upstream` ainda nao existir, uma configuracao possivel e:

```bash
git remote add upstream https://github.com/L4ki/Blur-Glassy.git
```

Verifique antes com:

```bash
git remote -v
```

## Creditos

Autor original: l4k1 <l4k1987@gmail.com>

Projeto original:

- https://github.com/L4ki/Blur-Glassy
- https://www.pling.com/u/l4k1/

Este fork preserva autoria, creditos e licenca originais.

## Licenca

GPLv3. Consulte `LICENSE`.
