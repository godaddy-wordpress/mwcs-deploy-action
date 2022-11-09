# mwcs-deploy-action
Github Action for use in Workflows to deploy to GoDaddy Managed WooCommerce Stores

## Inputs

| Name            | Requirement | Description |
| --------------- | ----------- | ----------  |
| `MWCS_INTEGRATION_SECRET` | _required_ | Authentication token
| `MWCS_INTEGRATION_ID`     | _required_ | Unique id for the integration
| `MWCS_APP_ID`             | _required_ | Id of the app you want to deploy to
| `MWCS_DEPLOY_DEST`        | _required_ | Set the subdirectory to deploy to. examples: /httpdocs, /httpdocs/wp-content/plugins/my-plugin |
| `MWCS_WORKING_DIR`        | _optional_ | The directory that you want deployed, based on the build files' path. example: "${{github.workspace}}"  |

## Outputs

## Example usage

```
on:
  push:
jobs:
  deploy:
    name: Deploy to My MWCS App
    runs-on: ubuntu-20.04
    steps:
      - name: Checkout repo
        uses: actions/checkout@v2
      - name: Run deploy
        uses: godaddy-wordpress/mwcs-deploy-action@v1
        with:
          MWCS_DEPLOY_DEST: "/httpdocs/wp-content/"
          MWCS_INTEGRATION_SECRET: ${{secrets.MWCS_INTEGRATION_SECRET}}
          MWCS_INTEGRATION_ID: ${{secrets.MWCS_INTEGRATION_ID}}
          MWCS_APP_ID: ${{secrets.MWCS_APP_ID}}
          MWCS_WORKING_DIR: "${{github.workspace}}" # use the files starting at the repository root
```
