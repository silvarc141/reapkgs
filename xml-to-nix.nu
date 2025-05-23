#!/usr/bin/env nu

def cleanup_reapack_index [xml_content: string] {
    $xml_content 
    | from xml
    | get content 
    | where tag == category 
    | reject tag
    | flatten 
    | rename -c {name: category}
    | insert name {|row| $row.content.attributes.name}
    | insert type {|row| $row.content.attributes.type}
    | insert description {|row| $row.content.attributes.desc}
    | insert source {|outer_row| $outer_row.content.content | where tag == version 
        | insert version {|row| $row.attributes.name}
        | insert author {|row| $row.attributes.author}
        | insert time {|row| $row.attributes.time | into datetime}
        | insert links {|row| $row.content | where tag == source | first | get content | get content}
        | sort-by time --reverse
        | reject tag attributes content
    }
    | reject content
    | move --first name type category description
}

def prefetch_hash [file: string, url: string] {
    let name = (sanitize_name (basename $url))
    let redirected_url = (http get $url --headers | get headers.location | default $url)
    let sha256 = nix-prefetch-url $redirected_url --name $name

    if $sha256.exit_code == 0 {
        $"($file)|($url)|($sha256.stdout | str trim)"
    } else {
        error make {msg: $"Error prefetching ($redirected_url) (redirected from ($url))"}
    }
}

# http get https://github.com/MichaelPilyavskiy/ReaScripts/raw/master/index.xml 
