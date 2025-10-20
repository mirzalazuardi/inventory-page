require 'pagy/extras/headers'
require 'pagy/extras/overflow'

Pagy::DEFAULT[:items] = 20
Pagy::DEFAULT[:max_items] = 100
Pagy::DEFAULT[:overflow] = :last_page
Pagy::DEFAULT[:headers] = {
  page: 'Page',
  items: 'Per-Page',
  count: 'Total',
  pages: 'Total-Pages'
}
