# 충돌방지
RUN python -m pip show google && python -m pip uninstall -y google || true \
    python -m pip install -U pip setuptools wheel \
    python -m pip install -U google-adk mcp 

print("도커 시작.")
