# Contribution Guidelines

## Licensing
By contributing code, documentation or media files ("The Material") to the project ("RintCore"),
you hereby atest to owning the copyright on the material, or having the right to sublicense the
material. You hereby agree to provide the material to the project under the "GPL v3" license or
a later version of it. This license is located in the LICENSE.md file.

### Submitting a new issue

If you want to ensure that your issue gets fixed *fast* you should
attempt to reproduce the issue in an isolated example application that
you can share.

### Making a pull request

If you'd like to submit a pull request please adhere to the following:

1. Your code *must* be tested. Please TDD your code! (where ever possible)
2. do modifications on an appropriately named branch.
3. No single-character variables
4. Two-spaces instead of tabs
5. Single-quotes instead of double-quotes unless you are using string
   interpolation or escapes.
6. General Rails/Ruby naming conventions for files and classes
7. Have your commit message prefixed with the class it impacts Eg.: [PrinterDriver] Made it more awesome.
8. A single commit can only impact one class. If your changes impact multiple classes, then
   your pull request must have multiple commits.

Plase note that you must adhere to each of the above mentioned rules.
Failure to do so will result in an immediate closing of the pull
request. If you update and rebase the pull request to follow the
guidelines your pull request will be re-opened and considered for
inclusion.
