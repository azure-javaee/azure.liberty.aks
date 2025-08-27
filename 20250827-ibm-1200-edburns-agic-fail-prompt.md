# PROMPT

I am trying to get a workflow working. There is a lot of template substitution among the files attached in the context. For example, the maven resources plugin is used to ensure values are templated from their definitions.

The file `validation-plan.json` is an input to this substitution system. It defines scenarios for testing with GitHub actions workflows.

You made changes in commit 25b309e3eaa18be19d89cda929e28bf5f004232c and when I ran the same workflow, I saw this error:

89ea15c7a8c3/providers/Microsoft.Resources/deployments/f28a4688-0052-4c4a-ade1-c310dcb2b89c","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.","details":[***"code":"RoleDefinitionDoesNotExist","message":"The specified role definition with ID 

Did you hallucinate that role definition?

Please analyze your changes in commit 25b309e3eaa18be19d89cda929e28bf5f004232c and propose a solution.
