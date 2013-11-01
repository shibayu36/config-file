function percol-perl-prove-test-class () {
    local selected_file=$(git ls-files t/ | percol)
    local selected_method=$(cat ${selected_file} | perl -ne '($method) = $_ =~ /sub\s+([^ ]+)\s+:\s+Test/; print "$method\n" if $method' | percol)
    BUFFER="TEST_METHOD=${selected_method} carton exec -- prove -v ${selected_file}"
    CURSOR=$#BUFFER
    zle clear-screen
}
zle -N percol-perl-prove-test-class
