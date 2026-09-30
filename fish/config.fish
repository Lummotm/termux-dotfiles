if status is-interactive
    set -g fish_greeting
end

if type -q starship
  starship init fish | source
end

if type -q zoxide 
  zoxide init fish | source
end

