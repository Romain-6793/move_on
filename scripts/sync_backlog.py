name: Sync Google Sheets Backlog to GitHub Project

on:
  workflow_dispatch:        # Déclenchement manuel
  schedule:
    - cron: '0 8 * * 1'    # Chaque lundi à 8h (optionnel)

jobs:
  sync:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: pip install google-auth google-auth-httplib2 google-api-python-client PyGithub requests

      - name: Run sync script
        env:
          GOOGLE_CREDENTIALS: ${{ secrets.GOOGLE_CREDENTIALS }}
          SPREADSHEET_ID: ${{ secrets.SPREADSHEET_ID }}
          GH_TOKEN: ${{ secrets.GH_TOKEN }}
          REPO_NAME: ${{ github.repository }}   # ex: "monorg/monrepo"
          SHEET_NAME: "Feuille 1"               # Nom de l'onglet dans ta sheet (à adapter)
          PROJECT_NUMBER: "1"                   # Numéro de ton GitHub Project
        run: python scripts/sync_backlog.py
