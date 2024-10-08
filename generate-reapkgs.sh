#!/usr/bin/env bash

sanitize_name() {
  iconv -f utf8 -t ascii//TRANSLIT |
  sed 's/%20/ /g
       s/+/plus/g
       s/[^[:alnum:]-]/-/g
       s/-\{2,\}/-/g
       s/^-//
       s/-$//
       s/^[^a-zA-Z]/_&/' | \
  tr '[:upper:]' '[:lower:]'
}

get_attrset_from_index() {
  local xml_file="$1"
  xmlstarlet sel -t \
    -v "/index/@name" -n \
    -m "/index/category/reapack/version" \
    -v "ancestor::reapack/@name" -n \
    -v "ancestor::category/@name" -n \
    -v "ancestor::reapack/@type" -n \
    -v "@name" -n \
    -m "source" \
    -v "." -n \
    -v "@file" -n \
    -b \
    -o "---END---" -n \
    "$xml_file" |
  {
    read -r index_name
    declare -A processed_packages
    while IFS= read -r package_name; do
      read -r category_name
      read -r package_type
      read -r version
      fullPackageName=$(echo "$package_name-$version" | sanitize_name)
      
      # Handle duplicates
      suffix=""
      counter=1
      while [[ -n "${processed_packages[$fullPackageName$suffix]}" ]]; do
        ((counter++))
        suffix="_$counter"
      done
      
      fullPackageName="$fullPackageName$suffix"
      processed_packages[$fullPackageName]=1
      
      sources=()
      while IFS= read -r url && [ "$url" != "---END---" ]; do
        read -r path
        sources+=("$(cat << EOF
        {
          path = ''${path}'';
          url = "${url}";
          sha256 = "";
        }
EOF
)")
      done
    cat << EOF
    ${fullPackageName} = mkReapackPackage {
      inherit stdenv fetchurl;
      name = "${fullPackageName}";
      indexName = "${index_name}";
      categoryName = "${category_name}";
      packageType = "${package_type}";
      sources = [
$(printf '%s\n' "${sources[@]}")
      ];
    };
EOF
    done
  }
}

generate_nix_from_index() {
  local dir="$1"
  local index_url="$2"
  index_name=$(curl -s -L "$index_url" | xmlstarlet sel -t -v "/index/@name" -n | sanitize_name)
  output_file="${dir}/${index_name}.nix"

  cat << EOF > "$output_file"
{
  mkReapackPackage, 
  stdenv, 
  fetchurl,
}: {
  ${index_name} = {
$(curl -s -L "$index_url" | get_attrset_from_index /dev/stdin)
  };
}
EOF
}

replace_hash() {
  local file="$1"
  local url="$2"
  local sha256="$3"
  sed -i "\\#url = \"$url\"#{ n; s#\".*\"#\"$sha256\"# }" "$file" || return 1
}

prefetch_hash() {
  local file="$1"
  local url="$2"
  local sha256
  local name
  name=$(basename "$url" | sanitize_name)
  url=$(curl -w "%{url_effective}\n" -I -L -s -S "$url" -o /dev/null)
  sha256=$(nix-prefetch-url "${url}" --name "$name")
  if ! $sha256; then
    echo "Error fetching $url" >&2
    return 1
  fi
  echo "$file|$url|$sha256"
}

print_help() {
  local name
  name="nix run github:silvarc141/reapkgs --"

  echo "Usage: $name [options]"
  echo "Options:"
  echo "  -h              Display this help message"
  echo "  -g              Generate indexes and related files"
  echo "  -p              Prefetch hashes for package sources"
  echo "  -r              Replace hashes in generated files"
  echo "  -o <directory>  Set output directory for generated files (if empty, use ./generated)"
  echo "  -i <file>       Specify a file containing newline-separated index URLs (if empty, use known repos)"
  echo "  -d <file>       Specify a file to store and read hash data (if empty, use temp file)"
  echo "  -j <processes>      Specify the number of processes to use for prefetching"
  echo "  -q              Do not create log files"
  echo "Examples:"
  echo "  $name -gpr                        # Create reapkgs flake for known repos' indexes"
  echo "  $name -gpr -i ./index-list.txt    # Create reapkgs flake for a custom index url list"
  echo "  $name -p -d ./new-hashes.txt      # Prefetch hash data of urls in nix files in default ./generated path to ./new-hashes.txt"
  echo "  $name -r -d ./old-hashes.txt      # Replace hashes in default ./generated path using hash data from ./old-hashes.txt"
  echo "  $name -p -j 4                     # Prefetch hash data using 4 cores"
}
generate=false
prefetch_hashes=false
replace_hashes=false
output_directory="./generated"
index_urls_path="" # if empty uses indexes from known repos
hash_data_path="" # if empty writes and reades from a temporary file
processes=""
no_logs=false

while getopts "o:i:d:j:gprhq" opt; do
  case $opt in
    h) print_help; exit 0 ;;
    g) generate=true ;;
    p) prefetch_hashes=true ;;
    r) replace_hashes=true ;;
    o) output_directory="$OPTARG" ;;
    i) index_urls_path="$OPTARG" ;;
    d) hash_data_path="$OPTARG" ;;
    j) processes="$OPTARG" ;;
    q) no_logs=true ;;
    \?) echo "Invalid option: -$OPTARG" >&2; print_help; exit 1 ;;
  esac
done
if [ "$no_logs" = false ]; then
  timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
  mkdir -p ./log
  log_file="./log/reapkgs-${timestamp}.log"
  exec > >(tee -a "$log_file") 2>&1
fi

if [ $# -eq 0 ]; then
  print_help
  exit 0
fi

index_output_subdir="$output_directory/reapack-packages"

index_urls=()
if [ -n "$index_urls_path" ]; then
  readarray -t index_urls < "$index_urls_path"
fi

if [ ${#index_urls[@]} -eq 0 ]; then
  echo "No urls passed, using known repos' indexes"
  readarray -t index_urls <<<"$(curl -s "https://reapack.com/repos.txt")"
fi

if [ "$generate" = true ] || [ "$prefetch_hashes" = true ]; then
  echo "Ensuring directory $output_directory exists"
  mkdir -p "$output_directory"
  echo "Ensuring directory $index_output_subdir exists"
  mkdir -p "$index_output_subdir"
fi

unexpand_newline() {
  sed ':a
      N
      $!ba
      s/\n/\\n/g'
}

if [ "$generate" = true ]; then
  echo "Generating nix from indexes..."
  total_indexes=${#index_urls[@]}
  current_index=0

  for index_url in "${index_urls[@]}"; do
    ((current_index++))
    echo "Processing index $current_index of $total_indexes: $index_url"
    generate_nix_from_index "$index_output_subdir" "$index_url" 
  done

  relative=$(dirname "$0")

  echo "Generating default.nix..."
  files=$(
    find "$index_output_subdir" -maxdepth 1 -name "*.nix" -not -name "default.nix" -printf './%P\n' | 
    sort | sed 's/^/    /g' | unexpand_newline
  )
  sed "s|.*#insert.*|${files}|g" > "${index_output_subdir}/default.nix" < "$relative/template-default.nix"

  echo "Generating flake.nix..."
  urls=$(
    printf '%s\n' "${index_urls[@]}" |
    sort | sed 's/^/    /g' | unexpand_newline
  )
  sed "s|.*#insert.*|${urls}|g" > "${output_directory}/flake.nix" < "$relative/template-flake.nix"

  echo "Copying mk-reapack-package.nix..."
  cp "$relative/mk-reapack-package.nix" "$output_directory/"
fi

if [ "$prefetch_hashes" = true ]; then
  echo "Prefetching hashes..."
  export -f prefetch_hash
  export -f sanitize_name
  tmpdir="$output_directory/parallel-tmp-dir"
  mkdir -p "$tmpdir"

  find "$index_output_subdir" -name "*.nix" ! -name "default.nix" -print0 |
  xargs -0 grep 'url = ' -H |
  sed 's|\(.*\):.*url = "\(.*\)";|\1\|\2|' |
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d '|' -f1)
    url=$(echo "$line" | cut -d '|' -f2-)
    echo "$file#$url"
  done | 
  parallel \
  ${processes:+"-j $processes"} \
  --no-notice \
  --tmpdir "$tmpdir" \
  --colsep '#' prefetch_hash {1} {2} > "${hash_data_path:-hash.tmp}"

  rm -rf "$tmpdir"
fi

if [ "$replace_hashes" = true ]; then
  echo "Replacing hashes in files..."
  while IFS='|' read -r file url sha256; do
    if ! replace_hash "$file" "$url" "$sha256"; then
      echo "Failed to replace hash for $url in $file"
    fi
  done < "${hash_data_path:-hash.tmp}"
fi

if [ "$prefetch_hashes" = true ] && [ "$replace_hashes" = true ] && [ -z "$hash_data_path" ]; then
  echo "Cleaning up temporary hash file..."
  rm hash.tmp
fi
