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


def generate_issues_markdown():
    vm_issues = REPOSITORY.get_issues(labels=['container'])
    vm_issues_data = [[
        f'<a href={issue.url}>{issue.title} [#{issue.number}]</a>',
        fmt_labels(issue.labels), issue.state
    ] for issue in vm_issues]

    writer = ptw.MarkdownTableWriter(
        headers=["Title", "Labels", "Status"],
        value_matrix=vm_issues_data,
        column_styles=[
            Style(),
            Style(),
            Style(),
        ],  # specify styles for each column
    )
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
