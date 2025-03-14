#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# Packages are installed after nodes so we can fix them...

APT_PACKAGES=(
    #"package-1"
    #"package-2"
)

PIP_PACKAGES=(
    #"package-1"
    #"package-2"
)

NODES=(
    "https://github.com/Fannovel16/comfyui_controlnet_aux"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/chflame163/ComfyUI_LayerStyle"
    "https://github.com/yolain/ComfyUI-Easy-Use"
    "https://github.com/ai-shizuka/ComfyUI-tbox"
    # 8k upscale
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/storyicon/comfyui_segment_anything"
    "https://github.com/chflame163/ComfyUI_CatVTON_Wrapper"
    # Swap clothe
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/TTPlanetPig/Comfyui_TTP_Toolset"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
    "https://github.com/shiimizu/ComfyUI-TiledDiffusion"
    "https://github.com/kijai/ComfyUI-Florence2"
    "https://github.com/chrisgoringe/cg-use-everywhere"
    "https://github.com/TinyTerra/ComfyUI_tinyterraNodes"
    "https://github.com/gseth/ControlAltAI-Nodes"
    "https://github.com/TTPlanetPig/Comfyui_TTP_CN_Preprocessor"
    "https://github.com/un-seen/comfyui-tensorops"
    
)

WORKFLOWS=(

)

CHECKPOINT_MODELS=(
    "https://huggingface.co/SG161222/RealVisXL_V5.0_Lightning/resolve/main/RealVisXL_V5.0_Lightning_fp16.safetensors?download=true"
)

UNET_MODELS=(
)

LORA_MODELS=(
)

VAE_MODELS=(
)

ESRGAN_MODELS=(
)

CONTROLNET_MODELS=(
    "https://huggingface.co/brad-twinkl/controlnet-union-sdxl-1.0-promax/resolve/main/diffusion_pytorch_model.safetensors?download=true" "controlnet-union-sdxl-1.0-promax.safetensors"
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    provisioning_get_files \
        "${COMFYUI_DIR}/models/checkpoints" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/unet" \
        "${UNET_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/lora" \
        "${LORA_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/controlnet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/esrgan" \
        "${ESRGAN_MODELS[@]}"
    provisioning_print_end
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
            sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
            pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Downloading node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                   pip install --no-cache-dir -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip install --no-cache-dir -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_files() {
    if [[ -z $2 ]]; then return 1; fi
    
    dir="$1"
    mkdir -p "$dir"
    shift
    
    # Process array elements in pairs (URL and optional filename)
    while [[ $# -gt 0 ]]; do
        url="$1"
        custom_filename=""
        
        # Check if next parameter exists and is not a URL (treat as custom filename)
        if [[ $# -gt 1 && ! "$2" =~ ^https?:// ]]; then
            custom_filename="$2"
            shift  # Move to the custom filename
        fi
        
        printf "Downloading: %s\n" "${url}"
        if [[ -n "$custom_filename" ]]; then
            printf "Will be saved as: %s\n" "${custom_filename}"
            provisioning_download "${url}" "${dir}" "4M" "${custom_filename}"
        else
            provisioning_download "${url}" "${dir}"
        fi
        printf "\n"
        
        shift  # Move to the next URL or end
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Application will start now\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

# Download from $1 URL to $2 directory path with optional $3 dot bytes and $4 custom filename
function provisioning_download() {
    local url="$1"
    local dir="$2"
    local dotbytes="${3:-4M}"
    local custom_filename="$4"
    
    if [[ -n $HF_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    
    if [[ -n $custom_filename ]]; then
        # Download with custom filename
        if [[ -n $auth_token ]]; then
            wget --header="Authorization: Bearer $auth_token" -qnc --show-progress -e dotbytes="$dotbytes" -O "${dir}/${custom_filename}" "$url"
        else
            wget -qnc --show-progress -e dotbytes="$dotbytes" -O "${dir}/${custom_filename}" "$url"
        fi
    else
        # Download with original filename
        if [[ -n $auth_token ]]; then
            wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="$dotbytes" -P "$dir" "$url"
        else
            wget -qnc --content-disposition --show-progress -e dotbytes="$dotbytes" -P "$dir" "$url"
        fi
    fi
}

# Allow user to disable provisioning if they started with a script they didn't want
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi
