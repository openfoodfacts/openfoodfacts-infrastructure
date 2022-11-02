# Onboarding

Focusing on the developer onboarding process into a project is a very important
step to make a repository popular: no one wants to struggle for hours to setup
an application and start developing on it.

A streamlined and easy setup process is thus critical to having meaningful
contributions on an open-source repository.

## Rules of the OFF on-boarding process

The setup steps should be as simple as possible and stick by the following rules:

* **Respect the user's time**:
  * reduce the amount of time needed to setup a project to the least amount possible.
  * but also make it as fast as possible to take into account code modifications (ideally live reload, if needed a container restart)
* **Make it easy for non-developers to contribute**: the dev setup should not require a high comprehension of the application at hand.
* **Repeatable and tested developer workflow**: the dev setup should be automated and tested with every pull request to ensure that it does not break accidentally when making changes.
* **Make it possible to reach a wide audience**:
  try to make the dev deployment platform agnostic,
  at least for commands used to develop in a normal process.
  On windows, git comes with *git bash* which should be priviledge as a console. You can use symlink on windows.

The `make dev` command should work across all repos to streamline the applications setup process.