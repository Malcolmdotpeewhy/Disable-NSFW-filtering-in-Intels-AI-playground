import os
import sys
import subprocess
import re
import platform
import shutil

def check_command(cmd):
    return shutil.which(cmd) is not None

def prompt_and_exit(msg, url):
    print(f"ERROR: {msg}")
    print(f"Please download and install it from: {url}")
    print("After installing, please restart this script.")
    sys.exit(1)

def run_command(cmd, cwd=None, shell=False):
    print(f"Running: {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    try:
        subprocess.run(cmd, cwd=cwd, shell=shell, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Command failed with error: {e}")
        sys.exit(1)

def search_and_patch_backend(service_dir):
    print(f"Searching {service_dir} for backend Python files...")
    if not os.path.exists(service_dir):
        print(f"Warning: {service_dir} not found. Skipping backend patch.")
        return

    # Specifically target safety checker functions based on user example
    # e.g., def is_nsfw_image(img_path, model_path): ...
    # E.g. in comfyui_downloader.py it is `def nsfw_image(img_path: str, model_path: str):`

    # Python regex to match the definition and its body. We can just match the "def" line and replace everything after it
    # But since functions can span multiple lines, we can try to find functions that return boolean based on pipeline results.
    # We'll use a safer approach: identify files with "nsfw" or "vit-base-nsfw-detector".
    # For matching the function body, we can just replace the specific `def is_nsfw_image` or `def nsfw_image` entirely

    for root, _, files in os.walk(service_dir):
        for file in files:
            if file.endswith('.py'):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read()

                    if 'nsfw' in content.lower() or 'vit-base-nsfw-detector' in content.lower():
                        # We are looking for something like:
                        # def is_nsfw_image(...):
                        #     ...
                        # def nsfw_image(...):
                        #     ...

                        modified = False

                        # Match: def nsfw_image(...) or def is_nsfw_image(...)
                        # We capture the definition, then we consume all indented lines (including blank lines inside the block)
                        # We use a pattern that matches the function definition, then matches everything until the next non-whitespace or next definition.
                        # Using negative lookahead: match lines that either start with whitespace (indentation) or are empty
                        pattern = r'([ \t]*def (?:is_)?nsfw_image\s*\([^)]*\)\s*:\s*\n)(?:[ \t]+.*?\n|^\s*\n)*'

                        def replacer(match):
                            def_line = match.group(1)
                            # the group 1 has trailing newlines.
                            # Just add our return False
                            return f"{def_line}    return False\n\n"

                        new_content, count = re.subn(pattern, replacer, content, flags=re.MULTILINE)

                        if count > 0:
                            with open(filepath, 'w', encoding='utf-8') as f:
                                f.write(new_content)
                            print(f"Patched {filepath} ({count} safety check functions modified to return False)")
                            modified = True

                        if not modified:
                            print(f"Found related keywords in {filepath}, but no safety check functions to patch.")

                except Exception as e:
                    print(f"Could not read or process {filepath}: {e}")

def main():
    print("=== AI Playground NSFW Filter Disable Automation ===")

    # 1. Check Git
    if not check_command("git"):
        prompt_and_exit("Git is not installed or not in PATH.", "https://git-scm.com/downloads")

    # 2. Clone or Pull Repo
    repo_url = "https://github.com/intel/AI-Playground.git"
    branch = "3.0.0-alpha"
    target_dir = "AI-Playground"

    if os.path.exists(target_dir):
        print(f"Directory {target_dir} exists. Pulling latest changes...")
        run_command(["git", "pull", "origin", branch], cwd=target_dir)
    else:
        print(f"Cloning {repo_url} branch {branch}...")
        run_command(["git", "clone", "-b", branch, repo_url, target_dir])

    # 3. Patch Backend Python files
    service_dir = os.path.join(target_dir, "service")
    search_and_patch_backend(service_dir)

    # Patch comfyui custom nodes safety checker if it exists
    # "If in ComfyUI custom nodes (e.g., comfyui-deps/custom_nodes/ComfyUI-safety-checker/nodes.py), bypass by setting pil_images_sfw = pil_images."
    safety_checker_path = os.path.join(target_dir, "comfyui-deps", "custom_nodes", "ComfyUI-safety-checker", "nodes.py")
    if os.path.exists(safety_checker_path):
        with open(safety_checker_path, 'r', encoding='utf-8') as f:
            content = f.read()

        new_content, count = re.subn(r'pil_images_sfw\s*=\s*.*', 'pil_images_sfw = pil_images', content)
        if count > 0:
            with open(safety_checker_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Patched {safety_checker_path}")
        else:
            print(f"No changes made to {safety_checker_path} (pattern not found)")

    # 4. Patch Frontend TypeScript
    # WebUI/src/assets/js/store/imageGenerationPresets.ts: remove "NSFW" from negativePrompt strings
    presets_path = os.path.join(target_dir, "WebUI", "src", "assets", "js", "store", "imageGenerationPresets.ts")
    if os.path.exists(presets_path):
        with open(presets_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # e.g., change 'NSFW, low quality' to 'low quality'
        content = re.sub(r'(?i)nsfw,\s*', '', content)
        content = re.sub(r'(?i),\s*nsfw', '', content)
        content = re.sub(r'(?i)nsfw', '', content)

        with open(presets_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Patched {presets_path}")
    else:
        print(f"Warning: {presets_path} not found. Skipping.")

    # 5. Patch Vue.js
    # WebUI/src/views/WorkflowResult.vue: modify the template to always show the original image, removing any v-if="!result.isNSFW" conditions
    vue_path = os.path.join(target_dir, "WebUI", "src", "views", "WorkflowResult.vue")
    if os.path.exists(vue_path):
        with open(vue_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # As per user explicit prompt:
        # "modify the template to always show the original image, removing any v-if="!result.isNSFW" conditions and using <img :src="result.image" /> unconditionally."

        # In reality, the codebase might have logic like:
        # <img v-if="!result.isNSFW" :src="result.image" />
        # Or <img v-if="!result.isNSFW" ... />
        # We'll use a regex that handles typical v-if conditions related to NSFW or `isNSFW`.

        # 1. Replace `v-if="!result.isNSFW"` or similar conditions in `<img>` tags completely.
        # Actually, let's just make sure any `v-if` checking for NSFW is stripped from img tags:
        content = re.sub(r'<img([^>]*?)v-if="!?[a-zA-Z0-9_.]*nsfw[a-zA-Z0-9_.]*"([^>]*?)>', r'<img\1\2>', content, flags=re.IGNORECASE)

        # If the user's specific request "using <img :src="result.image" /> unconditionally" means we should literally ensure it exists,
        # let's replace any conditional logic around images that checks for NSFW.

        # We replace any logic checking for `result.isNSFW`
        # Because the Vue template might vary, we apply a more robust search.

        # In case the exact condition `v-if="!result.isNSFW"` is present:
        content = re.sub(r'v-if="!result\.isNSFW"', '', content)

        # In case there's a fallback image for blocked content like `<img ... v-if="result.isNSFW" />`
        content = re.sub(r'<img[^>]*?v-if="result\.isNSFW"[^>]*>', '', content)

        # Based on actual code in the repo, it often uses `isCurrentImageNsfwBlocked`:
        content = re.sub(r'<!-- NSFW Blocked Overlay -->\s*<div\s*v-if="[^"]*NsfwBlocked"[^>]*>.*?</div>\s*</div>\s*</div>', '', content, flags=re.DOTALL)
        content = re.sub(r'<!-- NSFW Blocked Overlay -->\s*<div\s*v-if="[^"]*nsfw[^"]*"[^>]*>.*?</div>\s*</div>\s*</div>', '', content, flags=re.IGNORECASE | re.DOTALL)

        with open(vue_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Patched {vue_path}")
    else:
        print(f"Warning: {vue_path} not found. Skipping.")

    # 6. Install Node.js Dependencies
    if not check_command("npm") and not check_command("node"):
        prompt_and_exit("Node.js (npm) is not installed or not in PATH.", "https://nodejs.org/")

    webui_dir = os.path.join(target_dir, "WebUI")
    if os.path.exists(webui_dir):
        print("Installing Node.js dependencies...")
        is_windows = platform.system() == "Windows"
        npm_cmd = "npm.cmd" if is_windows else "npm"
        run_command([npm_cmd, "install"], cwd=webui_dir)

        print("Building frontend...")
        run_command([npm_cmd, "run", "build"], cwd=webui_dir)
    else:
        print(f"Warning: WebUI directory {webui_dir} not found. Skipping npm install and build.")

    # 7. Install Python Dependencies
    if sys.version_info < (3, 10):
        prompt_and_exit(f"Python 3.10+ is required (found {sys.version_info.major}.{sys.version_info.minor}).", "https://python.org/downloads/")

    if os.path.exists(service_dir):
        print("Installing Python dependencies...")
        run_command([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"], cwd=service_dir)

        # 8. Run the App
        entry_script = "web_api.py"
        if os.path.exists(os.path.join(service_dir, "main.py")):
            entry_script = "main.py"

        if os.path.exists(os.path.join(service_dir, entry_script)):
            print(f"Starting application ({entry_script})... Press Ctrl+C to stop.")
            try:
                process = subprocess.Popen([sys.executable, entry_script], cwd=service_dir)
                process.wait()
            except KeyboardInterrupt:
                print("\nStopping application...")
                process.terminate()
        else:
            print(f"Warning: Entry script {entry_script} not found in {service_dir}.")
    else:
        print(f"Warning: Service directory {service_dir} not found. Skipping pip install and app run.")

if __name__ == "__main__":
    main()
