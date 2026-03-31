import os, json, requests
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
from github import Github

# ── Config ────────────────────────────────────────────────────────────────────
SPREADSHEET_ID  = os.environ["SPREADSHEET_ID"]
SHEET_NAME      = os.environ.get("SHEET_NAME", "Backlog")
GH_TOKEN        = os.environ["GH_TOKEN"]
REPO_NAME       = os.environ["REPO_NAME"]
PROJECT_NUMBER  = int(os.environ.get("PROJECT_NUMBER", "1"))

# ── Google Sheets ─────────────────────────────────────────────────────────────
def get_rows():
    creds_info = json.loads(os.environ["GOOGLE_CREDENTIALS"])
    creds = Credentials.from_service_account_info(
        creds_info,
        scopes=["https://www.googleapis.com/auth/spreadsheets.readonly"]
    )
    svc = build("sheets", "v4", credentials=creds)
    result = svc.spreadsheets().values().get(
        spreadsheetId=SPREADSHEET_ID,
        range=f"{SHEET_NAME}!A1:Z1000"
    ).execute()
    rows = result.get("values", [])
    if not rows:
        return []
    headers = [h.strip().lower() for h in rows[0]]
    return [dict(zip(headers, row)) for row in rows[1:] if any(row)]

# ── GitHub Issues ─────────────────────────────────────────────────────────────
def get_existing_titles(repo):
    """Récupère les titres des issues existantes pour éviter les doublons."""
    return {i.title for i in repo.get_issues(state="all")}

def create_issue(repo, row):
    kwargs = {"title": row.get("title", "").strip()}
    if not kwargs["title"]:
        return None
    if row.get("body"):
        kwargs["body"] = row["body"]
    return repo.create_issue(**kwargs)

# ── GitHub Project (v2) ───────────────────────────────────────────────────────
def get_project_id(owner, project_number, is_org=True):
    query = """
    query($owner: String!, $number: Int!) {
      %s(login: $owner) {
        projectV2(number: $number) { id }
      }
    }
    """ % ("organization" if is_org else "user")
    r = requests.post(
        "https://api.github.com/graphql",
        json={"query": query, "variables": {"owner": owner, "number": project_number}},
        headers={"Authorization": f"Bearer {GH_TOKEN}"}
    )
    data = r.json()
    key = "organization" if is_org else "user"
    return data["data"][key]["projectV2"]["id"]

def add_issue_to_project(project_id, issue_node_id):
    mutation = """
    mutation($projectId: ID!, $contentId: ID!) {
      addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
        item { id }
      }
    }
    """
    requests.post(
        "https://api.github.com/graphql",
        json={"query": mutation, "variables": {"projectId": project_id, "contentId": issue_node_id}},
        headers={"Authorization": f"Bearer {GH_TOKEN}"}
    )

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    rows = get_rows()
    print(f"📋 {len(rows)} lignes trouvées dans la sheet")

    gh   = Github(GH_TOKEN)
    repo = gh.get_repo(REPO_NAME)
    owner, _ = REPO_NAME.split("/")

    existing = get_existing_titles(repo)
    print(f"ℹ️  {len(existing)} issues déjà présentes")

    # Détecte si owner est une org ou un user
    try:
        gh.get_organization(owner)
        is_org = True
    except Exception:
        is_org = False

    try:
        project_id = get_project_id(owner, PROJECT_NUMBER, is_org)
        print(f"✅ Project trouvé : {project_id}")
    except Exception as e:
        print(f"⚠️  Project introuvable ({e}), les issues seront créées sans être ajoutées au project")
        project_id = None

    created = 0
    skipped = 0
    for row in rows:
        title = row.get("title", "").strip()
        if not title:
            continue
        if title in existing:
            print(f"  ⏭  Déjà existante : {title}")
            skipped += 1
            continue
        issue = create_issue(repo, row)
        if issue:
            print(f"  ✅ Créée : {title}")
            existing.add(title)
            created += 1
            if project_id:
                add_issue_to_project(project_id, issue.node_id)

    print(f"\n🎉 Terminé — {created} créée(s), {skipped} ignorée(s)")

if __name__ == "__main__":
    main()
