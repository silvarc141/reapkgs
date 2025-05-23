#!/usr/bin/env nu

def reapack_index_xml_to_data [reapack_index_xml: string] {
    $reapack_index_xml 
    | from xml
    | get content 
    | where tag == category 
    | reject tag
    | flatten 
    | rename -c {name: category}
    | insert name {|row| $row.content.attributes.name}
    | insert type {|row| $row.content.attributes.type}
    | insert description {|row| $row.content.attributes.desc}
    | insert source {|outer_row| $outer_row.content.content 
        | where tag == version 
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

# Is it possible to get the final redirect with http get and remove curl dependency?
def get_final_redirect_url [] {
    curl -w "%{url_effective}\n" -I -L -s -S $in -o /dev/null
}

def prefetch_hash [] {
    let url = $in
    let sanitized_name =  $url | path parse | get stem | sanitize_name
    let url_redirected = $url | get_final_redirect_url
    let hash = nix-prefetch-url $url_redirected --name $sanitized_name e> /dev/null

    if $env.LAST_EXIT_CODE == 0 {
        $hash
    } else {
        error make {msg: $"Error prefetching ($url_redirected) \(redirected from ($url)\)"}
    }
}

def sanitize_name [] {
    $in 
    | url decode
    | str replace -a '+' 'plus' # replace "+" with "plus" (readability edge-case)
    | str replace -ar '[^[:alnum:]-]' '-' # replace non-alphanumeric characters with dashes
    | str replace -ar '-{2,}' '-' # remove all but one consequtive dashes
    | str replace -ar '^-' '' # remove leading dash
    | str replace -ar '-$' '' # remove following dash
    | str replace -ar '^[^a-zA-Z]' '_$0' # add an underscore if starting with a non-letter
    | str downcase
}
