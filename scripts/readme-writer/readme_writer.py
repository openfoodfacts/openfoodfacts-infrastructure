from github import Github
import os
import re
import pytablewriter as ptw
from pytablewriter.style import Style

ACCESS_TOKEN = os.environ.get('GITHUB_TOKEN')
GH_CLIENT = Github(ACCESS_TOKEN)
REPOSITORY = GH_CLIENT.get_repo("openfoodfacts/openfoodfacts-infrastructure")


def fmt_labels(labels):
    return ','.join([f'`{i.name}`' for i in labels])


TITLE_MAP = {
    'OS disk space': 'SSD (Local)',
    'Disk space': 'SSD (Local)',
    'Data disk space': 'HDD (Remote)',
    'Local disk space': 'SSD (Local)',
    'Shared disk space': 'HDD (Remote)',
    'Nb of CPU': 'CPU #',
    'Main software bricks': 'Services'
}
HEADERS = [
    'Title', 'State', 'OS', 'CPU #', 'RAM', 'SSD (Local)', 'HDD (Remote)',
    'Services'
]


def extract_request(body):
    regex = f'(?<=###).+?(?=###)'
    matches = re.findall(regex, body, re.DOTALL)
    map = {}
    for match in matches:
        title, content = tuple([m.strip() for m in match.splitlines() if m][:2])
        if title in TITLE_MAP:
            title = TITLE_MAP[title]
        map[title] = content
    return map


def generate_issues_markdown():
    open_issues = REPOSITORY.get_issues(labels=['container'], state='open')
    closed_issues = REPOSITORY.get_issues(labels=['container'], state='closed')
    vm_issues = list(open_issues) + list(closed_issues)
    rows = []
    reqs = []
    for issue in vm_issues:
        labels = [_.name for _ in issue.labels]
        if 'obsolete' in labels:
            continue
        req = extract_request(issue.body)
        # pprint.pprint(req)
        reqs.append(req)
        row = {
            'Title':
                f'<a href={issue.html_url}>{issue.title} [#{issue.number}]</a>',
            'State':
                issue.state,
            # 'Labels':
            # fmt_labels(issue.labels),
        }
        row.update(req)
        rows.append([row.get(key, '') for key in HEADERS])
    writer = ptw.MarkdownTableWriter(headers=HEADERS, value_matrix=rows)
    return writer.dumps()


def write_readme(issues_table: str):
    readme_content = open('README.md', 'r').read()

    # Replace existing issues table with updated one
    content = re.sub(r'(?<=<!-- VM table -->).+?(?=<!-- VM table -->)',
                     '\n' + issues_table,
                     readme_content,
                     flags=re.DOTALL)

    with open('README.md', 'w') as f:
        f.write(content)


if __name__ == '__main__':
    table_md = generate_issues_markdown()
    write_readme(table_md)
