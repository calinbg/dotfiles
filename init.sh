pip install --upgrade pip
#!/usr/bin/env bash

set -uo pipefail

# Interactive init script for dotfiles setup.
# Allows running selected steps, running all steps, and viewing progress.

TERM_WIDTH=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}

reset_colors() {
	printf '\033[0m'
}

red() { printf '\033[31m'; }
green() { printf '\033[32m'; }
yellow() { printf '\033[33m'; }
blue() { printf '\033[34m'; }
cyan() { printf '\033[36m'; }
bold() { printf '\033[1m'; }

declare -a STEP_NAMES
declare -a STEP_DESCRIPTIONS
declare -a STEP_FUNCS
declare -a STEP_STATUS

STATUS_PENDING="pending"
STATUS_RUNNING="running"
STATUS_DONE="done"
STATUS_FAILED="failed"

append_step() {
	STEP_NAMES+=("$1")
	STEP_DESCRIPTIONS+=("$2")
	STEP_FUNCS+=("$3")
	STEP_STATUS+=("$STATUS_PENDING")
}

run_with_spinner() {
	local command_text="$1"
	local label="$2"
	local logfile="/tmp/init-step-${step_index}.$$.log"
	local spin='|/-\\'
	local i=0

	printf '%s' "$label"
	set +e
	bash -lc "$command_text" >"$logfile" 2>&1 &
	local pid=$!

	while kill -0 "$pid" 2>/dev/null; do
		printf '\b%s' "${spin:i%4:1}"
		sleep 0.1
		((i++))
	done

	wait "$pid"
	local rc=$?
	printf '\b'
	if [[ $rc -eq 0 ]]; then
		printf '%s\n' "$(green)OK$(reset_colors)"
	else
		printf '%s\n' "$(red)FAIL$(reset_colors)"
		printf '%s\n' "$(yellow)Log: $logfile$(reset_colors)"
	fi
	set -e
	return $rc
}

execute_step() {
	local index=$1
	local step_name=${STEP_NAMES[$index]}
	local step_func=${STEP_FUNCS[$index]}

	STEP_STATUS[$index]=$STATUS_RUNNING
	draw_menu
	printf '\n%s %s\n' "$(bold)Running step #$((index + 1)):$(reset_colors)" "$step_name"
	if $step_func; then
		STEP_STATUS[$index]=$STATUS_DONE
		echo "$(green)Step completed.$(reset_colors)"
	else
		STEP_STATUS[$index]=$STATUS_FAILED
		echo "$(red)Step failed. Review the log above.$(reset_colors)"
	fi
}

draw_line() {
	printf '%*s\n' "$TERM_WIDTH" '' | tr ' ' '─'
}

step_status_symbol() {
	case "$1" in
		"$STATUS_DONE") printf '%s' "$(green)✔$(reset_colors)" ;;
		"$STATUS_FAILED") printf '%s' "$(red)✖$(reset_colors)" ;;
		"$STATUS_RUNNING") printf '%s' "$(yellow)…$(reset_colors)" ;;
		*) printf '%s' "$(cyan)·$(reset_colors)" ;;
	esac
}

draw_menu() {
	clear
	printf '%s\n' "$(blue)$(bold)Dotfiles Init Runner$(reset_colors)"
	draw_line
	printf '%s\n' "Select a step to run or use a command below."
	printf '%s\n\n' "$(yellow)a$(reset_colors) = run all | $(yellow)n$(reset_colors) = next pending | $(yellow)q$(reset_colors) = quit"

	for i in "${!STEP_NAMES[@]}"; do
		local idx=$((i + 1))
		printf '%2d. %s %-52s %s\n' "$idx" "$(bold)${STEP_NAMES[$i]}$(reset_colors)" "${STEP_DESCRIPTIONS[$i]}" "$(step_status_symbol ${STEP_STATUS[$i]})"
	done
}

run_all_steps() {
	for i in "${!STEP_NAMES[@]}"; do
		if [[ ${STEP_STATUS[$i]} != "$STATUS_DONE" ]]; then
			execute_step "$i"
		fi
	done
}

run_next_step() {
	for i in "${!STEP_NAMES[@]}"; do
		if [[ ${STEP_STATUS[$i]} == "$STATUS_PENDING" ]]; then
			execute_step "$i"
			return
		fi
	done
	echo "All steps are already complete."
}

step_update_system() {
	run_with_spinner "DEBIAN_FRONTEND=noninteractive sudo apt-get update && DEBIAN_FRONTEND=noninteractive sudo apt-get -y upgrade" "Updating system... "
}

step_remove_packages() {
	run_with_spinner "sudo apt-get -y remove vim-tiny firefox" "Removing legacy packages... "
}

step_install_essentials() {
	run_with_spinner "sudo apt-get -y install $(grep -v '^#' ./data/essentials.list | xargs)" "Installing essentials... "
}

step_install_extras() {
	run_with_spinner "bash ./data/ppa.sh" "Installing extra repositories and packages... "
}

step_install_development() {
	run_with_spinner "sudo apt-get -y install $(grep -v '^#' ./data/development.list | xargs)" "Installing development packages... "
}

step_install_ohmyzsh() {
	run_with_spinner "wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh" "Installing Oh My Zsh... "
	run_with_spinner "chsh -s $(which zsh)" "Switching shell to zsh... "
}

step_install_vim_spf13() {
	run_with_spinner "curl http://j.mp/spf13-vim3 -L -o - | sh" "Installing spf13-vim... "
}

step_install_snaps() {
	run_with_spinner "bash ./data/snaps.sh" "Installing snaps... "
}

step_setup_npm() {
	run_with_spinner "wget -O- https://raw.githubusercontent.com/glenpike/npm-g_nosudo/master/npm-g-nosudo.sh | zsh" "Installing npm no-sudo wrapper... "
	run_with_spinner "npm install -g yarn eslint sass-lint typescript json-server nodemon" "Installing global npm tools... "
}

step_install_composer() {
	run_with_spinner "php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\" && php composer-setup.php && php -r \"unlink('composer-setup.php');\" && sudo mv composer.phar /usr/local/bin/composer" "Installing Composer... "
}

step_install_python_packages() {
	run_with_spinner "git clone --depth=1 git@github.com:prototorpedo/talib-precision-fix.git talib && cd talib && ./configure --prefix=/usr && make && sudo make install && cd .." "Building talib fix... "
	run_with_spinner "pip install --upgrade pip" "Upgrading pip... "
	run_with_spinner "pip install $(grep -v '^#' ./data/pip.list | xargs)" "Installing Python packages... "
}

step_install_irkernel() {
	run_with_spinner "Rscript -e \"install.packages('IRkernel')\"" "Installing IRkernel... "
	run_with_spinner "Rscript -e \"IRkernel::installspec()\"" "Registering IRkernel... "
	run_with_spinner "jupyter labextension install @techrah/text-shortcuts" "Installing Jupyter Lab extension... "
}

step_setup_docker() {
	run_with_spinner "sudo systemctl enable docker.service && sudo systemctl start docker.service" "Enabling and starting Docker... "
	run_with_spinner "sudo groupadd -f docker && sudo gpasswd -a $USER docker" "Adding user to docker group... "
}

step_copy_dotfiles() {
	run_with_spinner "cp -TRv ./files/ $HOME/" "Copying dotfiles to home... "
}

step_run_ai_tools() {
	run_with_spinner "bash ./ai-tools.sh" "Running AI tools installer... "
}

main() {
	append_step "Update system" "Update apt cache and upgrade packages" step_update_system
	append_step "Remove legacy packages" "Remove vim-tiny and firefox" step_remove_packages
	append_step "Install essentials" "Install base packages from data/essentials.list" step_install_essentials
	append_step "Install extras" "Install PPA and extras from data/ppa.sh" step_install_extras
	append_step "Install development" "Install development packages from data/development.list" step_install_development
	append_step "Install Oh My Zsh" "Download and configure Oh My Zsh" step_install_ohmyzsh
	append_step "Install spf13-vim" "Install spf13 Vim configuration" step_install_vim_spf13
	append_step "Install snaps" "Run snap installer script" step_install_snaps
	append_step "Setup npm" "Install npm global packages and helpers" step_setup_npm
	append_step "Install Composer" "Install PHP Composer" step_install_composer
	append_step "Install Python packages" "Build talib and install pip packages" step_install_python_packages
	append_step "Install IRKernel" "Install R kernel for Jupyter and lab extensions" step_install_irkernel
	append_step "Setup Docker" "Enable Docker service and group membership" step_setup_docker
	append_step "Copy dotfiles" "Copy files/ contents into home directory" step_copy_dotfiles
	append_step "Run AI tools" "Run ai-tools.sh script" step_run_ai_tools

	if [[ ${1:-} == "--run-all" ]]; then
		run_all_steps
		return
	fi

	while true; do
		draw_menu
		printf '\nEnter step number, command, or '
		yellow; printf 'h'
		reset_colors; printf ' for help: '
		read -r choice

		case "$choice" in
			a|A)
				run_all_steps
				;;
			n|N)
				run_next_step
				;;
			h|H)
				cat <<'EOF'
Available commands:
	a    Run all pending steps
	n    Run next pending step
	q    Quit the runner
	h    Show this help message
	<num> Run the numbered step
EOF
				read -rsp $'Press any key to continue...'
				;;
			q|Q)
				printf '\nExiting.\n'
				return
				;;
			'' )
				;;
			*)
				if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#STEP_NAMES[@]})); then
					execute_step $((choice - 1))
				else
					printf '%s\n' "$(red)Invalid selection.$(reset_colors)"
					sleep 1
				fi
				;;
		esac
		printf '\nPress enter to continue...'
		read -r
	done
}

main "$@"
