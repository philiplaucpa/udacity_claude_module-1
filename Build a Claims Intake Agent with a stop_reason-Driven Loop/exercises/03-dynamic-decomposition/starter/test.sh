export ANTHROPIC_API_KEY=voc-148141574921610651278776a89c3df6240d9.38543639
export ANTHROPIC_BASE_URL="https://claude.vocareum.com"
python -m claims_intake.run --all
pytest tests/ -v