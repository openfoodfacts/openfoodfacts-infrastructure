# Open Food Facts Query

The Open Food Facts Query project compute aggreations requests that are visible on the website as the user use the option "Explore products by".
It avoid using MongoDB for such tasks, giving faster results.

The repository is at : https://github.com/openfoodfacts/openfoodfacts-query/

## Production deployment

It is deployed in a specific Proxmox container (CT 115) on off1, using docker-compose.

Specific options are applyed to the container to host a docker. See [2024-02-12

## Staging deployment

It is deployed on the staging dockers VM as a docker-compose project. And available at https://query.openfoodfacts.net/

The `/var/lib/docker/volumes` is mounted on a specific ZFS dataset to host it on the NVME pool.

## Testing

The app is a replacement to mongodb aggregations queries, so it accepts such aggregations.

You can test it's working using:
```bash
curl -d '[{"$match": {"countries_tags": "en:france"}},{"$group":{"_id":"$brands_tags"}}]' -H "Content-Type: application/json" https://query.openfoodfacts.org/aggregate
```
