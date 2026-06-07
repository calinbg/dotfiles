#!bin/bash

sudo apt-get update && sudo apt-get upgrade

sudo apt-get remove vim-tiny firefox

echo "Essentials..."
sudo apt-get install $(cat ./data/essentials.list | grep -v '#')
echo "Done essentials..."
sleep 1

echo "Extras..."
bash ./data/ppa.sh
echo "Done extras..."
sleep 1

echo "Development..."
sudo apt-get install $(cat ./data/development.list | grep -v '#')
echo "Done development..."
sleep 1

wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh
chsh -s $(which zsh)

echo "Done ohmyzsh..."
sleep 1

### Vim spf13 -
curl http://j.mp/spf13-vim3 -L -o - | sh

echo "####### Done vim spf..."
sleep 1
cd
### Snaps
bash ./data/snaps.sh

### npm no sudo
wget -O- https://raw.githubusercontent.com/glenpike/npm-g_nosudo/master/npm-g-nosudo.sh | zsh

npm install -g yarn eslint sass-lint typescript json-server nodemon

echo "####### Done npm no sudo + globals..."
sleep 1

# composer (php)

php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php
php -r "unlink('composer-setup.php');"
sudo mv composer.phar /usr/local/bin/composer

read -n "####### Done composer..."

# Python stuff
# talib
git clone git@github.com:prototorpedo/talib-precision-fix.git talib
cd talib
./configure --prefix=/usr
make
sudo make install

cd ..
pip install --upgrade pip
pip install $(cat ./data/pip.list | grep -v '#')

# IRKernel
zsh -G
Rscript -e "install.packages('IRkernel')"
Rscript -e "IRkernel::installspec()"
jupyter labextension install @techrah/text-shortcuts

## docker
systemctl enable docker.service
systemctl start docker.service

# Add firewall rule
#sudo firewall-cmd --permanent --zone=trusted --add-interface=docker0

sudo groupadd docker
sudo gpasswd -a $USER docker

# .zshrc, bash_aliases, bash_functions, etc.
cp -TRv ./files/ $HOME/

# AI tools, etc.
bash ./ai-tools.sh

echo "Done!!!!"
