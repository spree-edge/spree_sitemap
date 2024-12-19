module SpreeSitemap::SpreeDefaults
  include Spree::Core::Engine.routes.url_helpers
  include Spree::BaseHelper # for meta_data

  def default_url_options
    { host: SitemapGenerator::Sitemap.default_host }
  end

  def add_login(options = {})
    add(login_path, options)
  end

  def add_signup(options = {})
    add(signup_path, options)
  end

  def add_account(options = {})
    add(account_path, options)
  end

  def add_password_reset(options = {})
    add(new_spree_user_password_path, options)
  end

  def add_products(options = {})
    active_products = Spree::Product.active.distinct
    Spree::Store.default.supported_locales.split(',').each do |locale|
      add(products_path(locale: locale), options.merge(lastmod: active_products.last_updated))
      active_products.each do |product|
        add_product(product, options, locale)
      end
    end
  end

  def add_product(product, options = {}, locale)
    opts = options.merge(lastmod: product.updated_at)

    if gem_available?('spree_videos') && product.videos.present?
      # TODO: add exclusion list configuration option
      # https://sites.google.com/site/webmasterhelpforum/en/faq-video-sitemaps#multiple-pages

      # don't include all the videos on the page to avoid duplicate title warnings
      primary_video = product.videos.first
      opts.merge!(video: [video_options(primary_video.youtube_ref, product)])
    end
    add(product_path(product, locale: locale), opts)
  end

  def add_pages(options = {})
    # TODO: this should be refactored to add_pages & add_page

    Spree::CmsPage.active.each do |page|
      add(page.path, options.merge(lastmod: page.updated_at))
    end if gem_available? 'spree_essential_cms'

    Spree::CmsPage.visible.each do |page|
      add(page.slug, options.merge(lastmod: page.updated_at))
    end if gem_available? 'spree_static_content'
  end

  def add_taxons(options = {})
    Spree::Store.default.supported_locales.split(',').each do |locale|
      Spree::Taxon.roots.each { |taxon| add_taxon(taxon, options, locale) }
    end
  end

  def add_taxon(taxon, options = {}, locale)
    add(nested_taxons_path(locale, taxon.permalink), options.merge(lastmod: taxon.products.last_updated)) if taxon.permalink.present?
    taxon.children.each { |child| add_taxon(child, options, locale) }
  end

  def gem_available?(name)
    Gem::Specification.find_by_name(name)
  rescue Gem::LoadError
    false
  rescue
    Gem.available?(name)
  end

  def main_app
    Rails.application.routes.url_helpers
  end

  private

  ##
  # Multiple videos of the same ID can exist, but all videos linked in the sitemap should be inique
  #
  # Required video fields:
  # http://www.seomoz.org/blog/video-sitemap-guide-for-vimeo-and-youtube
  #
  # YouTube thumbnail images:
  # http://www.reelseo.com/youtube-thumbnail-image/
  #
  # NOTE title should match the page title, however the title generation isn't self-contained
  # although not a future proof solution, the best (+ easiest) solution is to mimic the title for product pages
  #   https://github.com/spree/spree/blob/1-3-stable/core/lib/spree/core/controller_helpers/common.rb#L39
  #   https://github.com/spree/spree/blob/1-3-stable/core/app/controllers/spree/products_controller.rb#L41
  #
  def video_options(youtube_id, object = false)
    ({ description: meta_data(object)[:description] } rescue {}).merge(
      ({ title: [Spree::Config[:site_name], object.name].join(' - ') } rescue {})
    ).merge(
      thumbnail_loc: "http://img.youtube.com/vi/#{youtube_id}/0.jpg",
      player_loc: "http://www.youtube.com/v/#{youtube_id}",
      autoplay: 'ap=1'
    )
  end
end