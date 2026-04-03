import os, json, requests
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
from github import Github

# ── Config ────────────────────────────────────────────────────────────────────
SPREADSHEET_ID = os.environ["SPREADSHEET_ID"]
SHEET_NAME     = os.environ.get("SHEET_NAME", "Backlog")
GH_TOKEN       = os.environ["GH_TOKEN"]
REPO_NAME      = os.environ["REPO_NAME"]
PROJECT_NUMBER = int(os.environ.get("PROJECT_NUMBER", "1"))

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

# ── GitHub GraphQL ────────────────────────────────────────────────────────────
def graphql(query, variables):
    r = requests.post(
        "https://api.github.com/graphql",
        json={"query": query, "variables": variables},
        headers={"Authorization": f"Bearer {GH_TOKEN}"}
    )
    return r.json()

def delete_issue(node_id):
    graphql("""
        mutation($id: ID!) {
          deleteIssue(input: {issueId: $id}) {
            repository { name }
          }
        }
    """, {"id": node_id})

# ── GitHub Project (v2) ───────────────────────────────────────────────────────
def get_project_id(owner, project_number, is_org):
    q = """
    query($owner: String!, $number: Int!) {
      %s(login: $owner) {
        projectV2(number: $number) { id }
      }
    }
    """ % ("organization" if is_org else "user")
    data = graphql(q, {"owner": owner, "number": project_number})
    key = "organization" if is_org else "user"
    return data["data"][key]["projectV2"]["id"]

def add_to_project(project_id, node_id):
    graphql("""
        mutation($projectId: ID!, $contentId: ID!) {
          addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
            item { id }
          }
        }
    """, {"projectId": project_id, "contentId": node_id})

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    rows = get_rows()
    print(f"📋 {len(rows)} lignes trouvées dans la sheet")

    from github import Auth
    gh   = Github(auth=Auth.Token(GH_TOKEN))
    repo = gh.get_repo(REPO_NAME)
    owner, _ = REPO_NAME.split("/")

    # Charge toutes les issues existantes { titre: issue }
    existing = {i.title: i for i in repo.get_issues(state="open")}
    print(f"ℹ️  {len(existing)} issues ouvertes existantes")

    # Titres dans la sheet
    sheet_titles = {row.get("title", "").strip() for row in rows if row.get("title", "").strip()}

    # Détecte org ou user
    try:
        gh.get_organization(owner)
        is_org = True
    except Exception:
        is_org = False

    try:
        project_id = get_project_id(owner, PROJECT_NUMBER, is_org)
        print(f"✅ Project trouvé : {project_id}")
    except Exception as e:
        print(f"⚠️  Project introuvable ({e})")
        project_id = None

    created = updated = deleted = 0

    # 1. Supprime les issues qui ne sont plus dans la sheet
    for title, issue in existing.items():
        if title not in sheet_titles:
            delete_issue(issue.node_id)
            print(f"  🗑️  Supprimée : {title}")
            deleted += 1

    # 2. Crée ou met à jour les issues de la sheet
    for row in rows:
        title = row.get("title", "").strip()
        body  = row.get("body", "").strip()
        if not title:
            continue

        if title in existing:
            issue = existing[title]
            # Met à jour seulement si le body a changé
            if issue.body != body:
                issue.edit(body=body)
                print(f"  📝 Mise à jour : {title}")
                updated += 1
        else:
            # Crée la nouvelle issue
            kwargs = {"title": title}
            if body:
                kwargs["body"] = body
            issue = repo.create_issue(**kwargs)
            print(f"  ✅ Créée : {title}")
            created += 1
            if project_id:
                add_to_project(project_id, issue.node_id)

    print(f"\n🎉 Terminé — {created} créée(s), {updated} mise(s) à jour, {deleted} supprimée(s)")

if __name__ == "__main__":
    main()
