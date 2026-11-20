# Docker skeleton for the Phase 0 web build (G0–G1).
#
# G0 result (2026-11-20): official Godot 4.7.2 web build reports
# "Build configuration: Emscripten 4.0.20" (AZTechnology, verified 2026-11-04).
# Use this exact version for GDExtension web builds to avoid link/runtime mismatch.
#
# Usage (after pins are known):
#   docker build -f docker/web-build.Dockerfile \
#     --build-arg EMSDK_VERSION=<pinned> \
#     -t tvx-web-build:phase0 .

ARG EMSDK_VERSION=4.0.20
FROM emscripten/emsdk:${EMSDK_VERSION}

ARG GODOT_COMMIT=__PIN_IN_G0__
ARG VOXEL_TOOLS_COMMIT=__PIN_IN_G0__
ARG GODOTCPP_BRANCH=4.7

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3 \
    scons \
    ca-certificates \
    unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# 1. godot-cpp at the branch matching the pinned Godot.
RUN if [ "$GODOTCPP_BRANCH" = "__PIN_IN_G0__" ]; then \
      echo "ERROR: GODOTCPP_BRANCH is not pinned." >&2; exit 1; \
    fi && \
    git clone --depth 1 --branch "$GODOTCPP_BRANCH" https://github.com/godotengine/godot-cpp.git godot-cpp

# 2. Voxel Tools at the pinned commit (GDExtension-first).
RUN if [ "$VOXEL_TOOLS_COMMIT" = "__PIN_IN_G0__" ]; then \
      echo "ERROR: VOXEL_TOOLS_COMMIT is not pinned. See docs/GATES.md G0." >&2; exit 1; \
    fi && \
    git clone https://github.com/Zylann/godot_voxel.git voxel && \
    git -C voxel checkout "$VOXEL_TOOLS_COMMIT"

# 3. Build the GDExtension for the web platform.
#    Thread support requires COOP/COEP headers at serving time (infra/cloudflare/_headers).
#    dlink may be required for GDExtension on web; confirm in G1.
WORKDIR /src/voxel
RUN echo "TODO(G1): scons platform=web target=template_release threads=yes -j$(nproc)" && \
    echo "Verify the built .wasm/.side module loads with the official Godot 4.7.2 web template."

# 4. Output location (filled once the real build command is validated).
RUN mkdir -p /out && echo "Pinned build not yet implemented; see G1." > /out/README.txt

CMD ["bash", "-lc", "echo 'Phase 0 web build skeleton. Pins required. See docs/GATES.md.'"]
