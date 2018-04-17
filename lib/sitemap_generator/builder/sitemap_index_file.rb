module SitemapGenerator
  module Builder
    class SitemapIndexFile < SitemapFile

      # === Options
      #
      # * <tt>location</tt> - a SitemapGenerator::SitemapIndexLocation instance or a Hash of options
      #   from which a SitemapLocation will be created for you.
      def initialize(opts={})
        @location = opts.is_a?(Hash) ? SitemapGenerator::SitemapIndexLocation.new(opts) : opts
        @link_count = 0
        @sitemaps_link_count = 0
        @xml_content = '' # XML urlset content
        @xml_wrapper_start = <<-HTML
          <?xml version="1.0" encoding="UTF-8"?>
            <sitemapindex
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9
                http://www.sitemaps.org/schemas/sitemap/0.9/siteindex.xsd"
              xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
            >
        HTML
        @xml_wrapper_start.gsub!(/\s+/, ' ').gsub!(/ *> */, '>').strip!
        @xml_wrapper_end   = %q[</sitemapindex>]
        @filesize = SitemapGenerator::Utilities.bytesize(@xml_wrapper_start) + SitemapGenerator::Utilities.bytesize(@xml_wrapper_end)
        @written = false
        @reserved_name = nil # holds the name reserved from the namer
        @frozen = false      # rather than actually freeze, use this boolean

      end

      # Finalize sitemaps as they are added to the index.
      # If it's the first sitemap, finalize it but don't
      # write it out, because we don't yet know if we need an index.  If it's
      # the second sitemap, we know we need an index, so reserve a name for the
      # index, and go and write out the first sitemap.  If it's the third or
      # greater sitemap, just finalize and write it out as usual, nothing more
      # needs to be done.
      #
      # If a link is being added to the index manually as a string, then we
      # can assume that the index is required (unless create_index is false of course).
      # This seems like the logical thing to do.
      alias_method :super_add, :add
      def add(link, options={})
        if file = link.is_a?(SitemapFile) && link
          @sitemaps_link_count += file.link_count
          file.finalize! unless file.finalized?

          reserve_name unless @location.create_index == false
          file.write
          super(SitemapGenerator::Builder::SitemapIndexUrl.new(file, options))
        else
          # A link is being added manually.  Obviously the user wants an index.
          # This overrides the create_index setting.
          unless @location.create_index == false
            @create_index = true
            reserve_name
          end

          # Use the host from the location if none provided
          options[:host] ||= @location.host
          super(SitemapGenerator::Builder::SitemapIndexUrl.new(link, options))
        end
      end

      # Return a boolean indicating whether the sitemap file can fit another link
      # of <tt>bytes</tt> bytes in size.  You can also pass a string and the
      # bytesize will be calculated for you.
      def file_can_fit?(bytes)
        bytes = bytes.is_a?(String) ? SitemapGenerator::Utilities.bytesize(bytes) : bytes
        (@filesize + bytes) < SitemapGenerator::MAX_SITEMAP_FILESIZE && @link_count < SitemapGenerator::MAX_SITEMAP_FILES
      end

      # Return the total number of links in all sitemaps reference by this index file
      def total_link_count
        @sitemaps_link_count
      end

      def stats_summary(opts={})
        str = "Sitemap stats: #{number_with_delimiter(@sitemaps_link_count)} links / #{@link_count} sitemaps"
        str += " / %dm%02ds" % opts[:time_taken].divmod(60) if opts[:time_taken]
      end

      def finalize!
        raise SitemapGenerator::SitemapFinalizedError if finalized?
        reserve_name if create_index?
        @frozen = true
      end

      # Write out the index if an index is needed
      def write
        super if create_index?
      end

      # Whether or not we need to create an index file.  True if create_index is true
      # or if create_index is :auto and we have more than one link in the index.
      # If a link is added manually and create_index is not false, we force index
      # creation because they obviously intend for there to be an index.  False otherwise.
      def create_index?
        @create_index || @location.create_index == true || @location.create_index == :auto && @link_count > 1
      end

      # Return the index file URL.  If create_index is true, this is the URL
      # of the actual index file.  If create_index is false, this is the URL
      # of the first sitemap that was written out.  Only call this method
      # *after* the files have been finalized.
      def index_url
        @location.url
      end
    end
  end
end
