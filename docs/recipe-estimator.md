# Recipe Estimator

Attempts to determine the proportion of ingredients in a product from the nutrient information.

The repository is at : https://github.com/openfoodfacts/recipe-estimator/

## Production deployment

It is deployed in a specific Proxmox container (CT 115) on off1, using docker-compose.

Specific options are applyed to the container to host a docker. See [2024-02-12]

## Staging deployment

It is deployed on the staging dockers VM as a docker-compose project. And available at https://recipe-estimator.openfoodfacts.net/

## Testing

There is a UI that can be used to see the estimation for a particular product. e.g.

```
https://recipe-estimator.openfoodfacts.net/static/#3017620422003
```
