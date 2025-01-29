select (
    (length("https://world-en.openfoodfacts.org/product/")*count(url))
    + (length("https://images.openfoodfacts.org/images/products/")*(count(image_url)+count(image_small_url)))
  )/1000000
  as Mb from [all]
  