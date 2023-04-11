SOURCE_PATH="manual/main.texi"
DESTINATION_PATH="/tmp/guile-documenta/"
INDEX_FILE="index.html"

# TODO: Find out how to keep TOCs per chapter when enabling the menu.
# makeinfo --html --css-ref=https://luis-felipe.gitlab.io/texinfo-css/static/css/texinfo-7.css \
#          -c SHOW_TITLE=true -c FORMAT_MENU=menu \
#          -o $DESTINATION_PATH $SOURCE_PATH
makeinfo --html --css-ref=https://luis-felipe.gitlab.io/texinfo-css/static/css/texinfo-7.css \
         -c SHOW_TITLE=true \
         -o $DESTINATION_PATH $SOURCE_PATH
echo "GUILE-DOCUMENTA: Open file://$DESTINATION_PATH$INDEX_FILE in your Web browser to read the manual."
