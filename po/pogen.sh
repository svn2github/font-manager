#/bin/sh
cd ..
[ ! -e Makefile ] || make distclean
. release
./configure
make
cd po
cat >> POTFILES.in << EOF
[encoding: UTF-8]
src/constants.py
src/font-sampler.py
src/main.py
src/core/fonts.py
src/core/__init__.py
[type: gettext/glade]src/data/actions.ui
[type: gettext/glade]src/data/font-information.ui
[type: gettext/glade]src/data/font-manager.ui
[type: gettext/glade]src/data/font-sampler.ui
[type: gettext/glade]src/data/menus.ui
src/ui/actions.py
src/ui/export.py
src/ui/fontconfig.py
src/ui/library.py
src/ui/preferences.py
src/ui/previews.py
src/ui/sampler.py
src/ui/treeviews.py
src/utils/common.py
src/utils/xmlutils.py
EOF
cat >> header << EOF
# Copyright (C) 2009, 2010 Jerry Casiano
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above
#    copyright notice, this list of conditions and the following
#    disclaimer in the documentation and/or other materials provided
#    with the distribution.
#  * Neither the name of the author nor the names of contributors may
#    be used to endorse or promote products derived from this
#    software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

EOF
cp ../src/font-sampler ../src/font-sampler.py
intltool-update -p -x -g app
cd ../help/C/
xml2po -o ../../po/help.pot ./*.page
cd ../../po/
sed -i '1,5d' app.pot
cat header > font-manager.pot
cat header > font-manager-help.pot
cat app.pot >> font-manager.pot
cat help.pot >> font-manager-help.pot
URL="http://code.google.com/p/font-manager/issues/list"
sed -i  -e "s#PACKAGE\ VERSION#${VERSION}\ #g" \
-e "s#Report-Msgid-Bugs-To\:#Report-Msgid-Bugs-To\:\ ${URL}#g" *.pot
rm -f POTFILES.in header app.pot help.pot ../src/font-sampler.py
