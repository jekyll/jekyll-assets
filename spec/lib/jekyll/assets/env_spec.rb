require "rspec/helper"

describe Jekyll::Assets::Env do
  let :site do
    stub_jekyll_site
  end

  let :env do
    Jekyll::Assets::Env.new(
      site
    )
  end

  context :jekyll do
    it "responds" do
      expect(env).to respond_to(
        :jekyll
      )
    end

    it "matches site" do
      expect(env.jekyll).to eq(
        site
      )
    end
  end

  context :used do
    it "is a new set" do
      expect(env.used).to be_kind_of(
        Set
      )
    end
  end

  context :prefix_path do
    context "env == production" do
      before do
        allow(Jekyll).to receive(:env).and_return "production"
      end

      let :site do
        stub_jekyll_site({
          "assets"      => {
            "cdn"       => "https://cdn.example.com/",
            "digest"    => false,
            "compress"  => {
              "css"     => false,
              "js"      => false
            }
          }
        })
      end

      it "returns the cnd with a prefix" do
        expect(Jekyll::Assets::Env.new(site).prefix_path).to eq(
          "https://cdn.example.com/assets"
        )
      end
    end
  end

  context :digest? do
    context "Jekyll.env == production" do
      before do
        allow(Jekyll).to receive(:env).and_return(
          "production"
        )
      end

      let :site do
        stub_jekyll_site
      end

      it "digests by default" do
        expect(env.digest?).to eq(
          true
        )
      end

      it "compresses by default" do
        expect(env.compress?( "js")).to eq true
        expect(env.compress?("css")).to eq true
      end
    end

    context "Jekyll.env == test | development" do
      it "doesn't not digest by default" do
        %W(development test).each do |v|
          expect(env.digest?).to eq false
        end
      end
    end
  end

  it "overrides the default cache" do
    expect(env.cached).to be_kind_of(
      Jekyll::Assets::Cached
    )
  end

  it "sets the logger" do
    expect(env.logger).to be_kind_of(
      Jekyll::Assets::Logger
    )
  end

  it "patches asset context" do
    expect(env.context_class.method_defined?(:_old_asset_path)).to eq(
      true
    )
  end

  context :context_class do
    context :_asset_path do
      it "adds the asset to the used set" do
        env.find_asset("context", {
          :accept => "text/css"
        })

        expect(env.used.size).to eq 1
        expect(env.used.first.pathname.fnmatch?("*/context.jpg")).to eq(
          true
        )
      end
    end
  end

  context :config do
    it "allows users to set default sources" do
      old_value = site.config.delete("assets")
      site.config["assets"] = {
        "sources" => [
          "_foo/bar"
        ]
      }

      result = env.class.new(site).paths.grep(
        %r!fixture/_foo/bar\Z!
      )

      expect(result.size).to eq(1)
      site.config["assets"] = old_value
    end
  end

  it "sets up a cache" do
    expect(env.cache.instance_variable_get(:@cache_wrapper).cache).to be_kind_of(
      Sprockets::Cache::FileStore
    )
  end

  it "sets the JS compressor if asked to" do
    old_value = site.config.delete("assets")
    site.config["assets"] = {
      "compress" => {
        "js" => true
      }
    }

    result = env.class.new(site)
    expect(result.js_compressor).to eq(Sprockets::UglifierCompressor)
    site.config["assets"] = old_value
  end

  it "sets the CSS compressor if ask to" do
    old_value = site.config.delete("assets")
    site.config["assets"] = {
      "compress" => {
        "css" => true
      }
    }

    result = env.class.new(site)
    expect(result.css_compressor).to eq(Sprockets::SassCompressor)
    site.config["assets"] = old_value
  end

  context :compress? do
    it "should default to compression being off" do
      expect(env.compress?("css")).to eq false
      expect(env.compress?( "js")).to eq false
    end

    it "should allow compression if the user wants it" do
      allow(Jekyll).to receive(:env).and_return "development"
      old_value = site.config.delete("assets")
      site.config["assets"] = {
        "compress" => {
          "css" => true,
          "js"  => true
        }
      }

      expect(env.compress?("css")).to eq true
      expect(env.compress?( "js")).to eq true
      site.config["assets"] = old_value
    end
  end

  context do
    before :each do
      site.process
    end

    it "writes cached assets" do
      path = File.expand_path("../../../../fixture/_site/assets", __FILE__)
      FileUtils.rm_r(path)
      site.sprockets.used. \
        clear

      site.sprockets.class.digest_cache.each do |k, v|
        site.sprockets.class.digest_cache[k] = \
          "ShouldNotMatch"
      end

      site.sprockets.write_all
      expect(Dir[File.join(path, "*")].size).to eq(
        3
      )
    end
  end
end