# BookML: bookdown flavoured GitBook port for LaTeXML
# Copyright (C) 2021-26  Vincenzo Mantova <v.l.mantova@leeds.ac.uk>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

ifndef __bml.detect.mk.included
__bml.detect.mk.included :=

### Detect versions and check for updates

include bookml/bml-utils.mk
include bookml/bml-version.mk

# check for updates
.PHONY: check-for-update update
# if running from a Docker image
ifdef BOOKML_VERSION
check-for-update:
	@$(if $(call bml.version.lt,@VERSION@,$(BOOKML_VERSION)),$(call bml.print.echo,$(bml.print.yellow)BookML update $(BOOKML_VERSION) available$(bml.utils.comma) run `$(MAKE) update` to install it.))
	@:
update:
	@$(call bml.print.echo,$(bml.print.yellow)Replacing BookML @VERSION@ with $(BOOKML_VERSION).)
	@$(call bml.print.cmd,$(UNZIP) $(UNZIPFLAGS) /release.zip)
else
check-for-update:
	@$(if $(CURL),,$(call bml.print.echo,$(bml.print.red)Checking for updates requires curl, aborting. Visit https://github.com/vlmantova/bookml/releases to find the latest release.)exit 1)
	@$(eval bookml_release:=$$(if $$(CURL),$$(shell $$(CURL) -s https://api.github.com/repos/vlmantova/bookml/releases/latest)))
	@$(eval bookml_version:=$$(if $$(CURL),$$(word 3,$$(subst ", ,$$(filter "tag_name":_%,$$(subst "tag_name": ,"tag_name":_,$$(bookml_release)))))))
	@$(if $(CURL),$(call bml.print.echo,$(bml.print.yellow)$(if $(call bml.version.lt,@VERSION@,$(bookml_version)),BookML $(bookml_version) is newer than @VERSION@. Run `$(MAKE) update` to install it.,BookML @VERSION@ is already up to date.)))
	@:

update: | $(AUX_DIR)
	@$(if $(CURL),,$(call bml.print.echo,$(bml.print.red)Updating requires curl, aborting. Visit https://github.com/vlmantova/bookml/releases to find the latest release.)exit 1)
	@$(if $(CURL),$(if $(UNZIP),,$(call bml.print.echo,$(bml.print.red)Updating requires $(if $(bml.utils.iswin),tar.exe,unzip), aborting.)exit 1))
	@$(eval bookml_release:=$$(if $$(CURL),$$(if $$(UNZIP),$$(shell $$(CURL) -s https://api.github.com/repos/vlmantova/bookml/releases/latest))))
	@$(eval bookml_version:=$$(if $$(CURL),$$(if $$(UNZIP),$$(word 3,$$(subst ", ,$$(filter "tag_name":_%,$$(subst "tag_name": ,"tag_name":_,$$(bookml_release))))))))
	@$(eval bookml_update:=$$(if $(CURL),$$(if $$(UNZIP),$$(call bml.version.lt,@VERSION@,$$(bookml_version)))))
	@$(if $(bookml_update),$(call bml.print.echo,$(bml.print.yellow)BookML $(bookml_version) is newer than @VERSION@$(bml.utils.comma) updating.,BookML @VERSION@ is already up to date.))
	@$(if $(bookml_update),$(call bml.print.cmd,$(CURL) -L https://github.com/vlmantova/bookml/releases/download/$(bookml_version)/release.zip -o "$(AUX_DIR)/release.zip"))
	@$(if $(bookml_update),$(call bml.print.cmd,$(UNZIP) $(UNZIPFLAGS) "$(AUX_DIR)/release.zip"))
endif

# dump auxdir into zip file
.PHONY: aux-zip
aux-zip: | $(AUX_DIR)
	@$(call bml.rm,AUX.$(notdir $(AUX_DIR)).zip)
	@$(call bml.print.cmd,$(ZIP) --quiet --recurse-paths "AUX.$(notdir $(AUX_DIR)).zip" "$(AUX_DIR)")

# version detection targets
.NOTPARALLEL: detect
detect: detect-core detect-image detect-bmlimage detect-misc
	@:
.PHONY: detect-sources detect-bookml detect-make detect-tex detect-perl \
  detect-latexml detect-imagemagick detect-ghostscript detect-mutool \
  detect-dvisvgm detect-latexmk detect-texfot detect-preview detect-zip \
  detect-curl detect detect-core detect-image detect-bmlimage detect-misc \
  announce-detect-core announce-detect-image announce-detect-bmlimage \
  announce-detect-misc detect-pdftosvg-converter detect-pdftocairo

announce-detect-core:
	@$(call bml.print.redbox,     Required                                                                 )
	@:
detect-core: detect-sources detect-bookml detect-make detect-tex detect-perl detect-latexml detect-latexmk detect-zip
	@:
detect-sources: announce-detect-core
	@$(call bml.print.echo,$(bml.print.cyan)    Main files:$(if $(SOURCES) \
	  ,$(bml.print.green) $(SOURCES),$(bml.print.red) no .tex files with \documentclass found in this directory))
	@:
detect-bookml: announce-detect-core
	@$(call bml.print.testver,        BookML,,,@VERSION@)
	@:
detect-tex: announce-detect-core
	@$(eval tex_ver:=$$(subst  , ,$$(patsubst $$(bml.utils.openp)%,%,$$(filter $$(bml.utils.openp)%,$$(subst $$(bml.utils.closedp), , \
	  $$(subst $$(bml.utils.openp), $$(bml.utils.openp),$$(subst $$(bml.utils.space), ,$$(shell tex -version 2>$$(bml.utils.null)))))))))
	@$(call bml.print.testver,           TeX,,,$(tex_ver))
	@:
detect-make: announce-detect-core
	@$(call bml.print.testver,      GNU Make,3.81,4.4.1,$(MAKE_VERSION))
	@:
detect-perl: announce-detect-core
	@$(eval perl_ver:=$$(subst $$(bml.utils.closedp),,$$(subst $$(bml.utils.openp),,$$(firstword \
	  $$(filter $$(bml.utils.openp)%,$$(shell $$(PERL) --version 2>$$(bml.utils.null)))))))
	@$(call bml.print.testver,          perl,5.8.1,,$(perl_ver),)
	@:
detect-latexml: announce-detect-core
	@$(eval latexml_ver:=$$(subst $$(bml.utils.closedp),,$$(filter %$$(bml.utils.closedp), \
	  $$(shell $$(LATEXML) --VERSION 2>&1))))
	@$(call bml.print.testver,       LaTeXML,0.8.7,0.8.8,$(latexml_ver))
	@:
detect-latexmk: announce-detect-core
	@$(call bml.print.testver,       latexmk,,,$(lastword $(shell $(LATEXMK) --version 2>$(bml.utils.null))))
	@:
detect-zip: announce-detect-core
	@$(eval zip_ver := $$(firstword $$(subst Zip_,,\
	  $$(filter Zip_%,$$(subst Zip ,Zip_,$$(shell $(ZIP) -v 2>$$(bml.utils.null)))))))
	@$(call bml.print.testver,           zip,,,$(zip_ver))
	@:

announce-detect-image:
	@$(call bml.print.redbox,     Optional: for any image handling$(bml.utils.comma) including BookML images                )
	@:
detect-image: announce-detect-image detect-imagemagick detect-ghostscript detect-dvisvgm detect-mutool detect-inkscape detect-pdftocairo
	@:
detect-imagemagick: announce-detect-image
	@$(foreach suf,Magick Magick::Q16 Magick::Q16HDRI Magick::Q8, \
	  $(if $(magick_ver),,$(eval magick_ver:=$$(shell perl -MImage::$$(suf) -e "print Image::$$(suf)->VERSION" 2>$$(bml.utils.null) || :))))
	@$(call bml.print.testver, Image::Magick,,,$(magick_ver))
	@:
detect-epstosvg-converter: announce-detect-image
	@$(call bml.print.echo,$(bml.print.magenta) EPSTOSVG_CONVERTER is set to '$(EPSTOSVG_CONVERTER)')
	@:
detect-pdftosvg-converter: announce-detect-image
	@$(call bml.print.echo,$(bml.print.magenta) PDFTOSVG_CONVERTER is set to '$(PDFTOSVG_CONVERTER)')
	@:
.NOTPARALLEL: detect-ghostscript detect-dvisvgm
detect-ghostscript: announce-detect-image detect-epstosvg-converter detect-pdftosvg-converter
	@$(foreach bin, \
	  $(if $(bml.utils.iswin),gswin64c gswin64 gswin32c gswin32 mgs,gs), \
	  $(if $(gs_info),,$(eval gs_info:=$$(shell $$(bin) -v 2>$$(bml.utils.null)))))
	@$(eval gs_ver:=$$(firstword $$(subst Ghostscript_,,$$(filter Ghostscript_%,$$(subst Ghostscript ,Ghostscript_,$$(gs_info))))))
	@$(eval gs_ver:=$$(firstword $$(subst Ghostscript_,,$$(filter Ghostscript_%,$$(subst Ghostscript ,Ghostscript_,$$(gs_info))))))
	@$(call bml.print.testver,   Ghostscript,,,$(gs_ver), (BookML images, EPS/PDF to SVG via dvisvgm))
	@:
detect-dvisvgm: announce-detect-image detect-epstosvg-converter detect-pdftosvg-converter
	@$(eval dvisvgm_info:=$$(if $(DVISVGM),$$(shell $(DVISVGM) -V1 2>$$(bml.utils.null))))
	@$(eval dvisvgm_ver:=$$(firstword $$(subst dvisvgm_,,$$(filter dvisvgm_%,$$(subst $(DVISVGM) ,dvisvgm_,$$(dvisvgm_info))))))
	@$(eval gs_ver:=$$(wordlist 2,2,$$(subst &, ,$$(filter Ghostscript:%,$$(subst &Ghostscript:, Ghostscript:,$$(subst $$(bml.utils.space),&,$$(dvisvgm_info)))))))
	@$(eval mutool_ver:=$$(wordlist 2,2,$$(subst &, ,$$(filter mutool:%,$$(subst &mutool:, mutool:,$$(subst $$(bml.utils.space),&,$$(dvisvgm_info)))))))
	@$(eval needs_mutool:=$$(if $$(call bml.version.leq,10.01.0,$$(gs_ver)),true))
	@$(call bml.print.testver,       dvisvgm,1.6,2.7,$(dvisvgm_ver), (BookML images, EPS to SVG$(if $(needs_mutool),,, PDF to SVG via dvisvgm)))
	@$(call bml.print.testver, dvisvgm/libgs,,,$(gs_ver), (BookML images, EPS to SVG$(if $(needs_mutool),,, PDF to SVG via dvisvgm)))
	@$(if $(needs_mutool),$(call bml.print.testver,       dvisvgm,3.0,,$(dvisvgm_ver), (PDF to SVG via dvisvgm)))
	@$(if $(needs_mutool),$(call bml.print.testver,dvisvgm/mutool,,,$(mutool_ver), (PDF to SVG via dvisvgm)))
	@:
detect-inkscape: announce-detect-image detect-epstosvg-converter detect-pdftosvg-converter
	@$(eval inkscape_info:=$$(if $$(INKSCAPE),$$(shell $$(INKSCAPE) -V --without-gui 2>$$(bml.utils.null))))
	@$(eval inkscape_ver:=$$(if $$(filter-out Inkscape,$$(firstword $$(inkscape_info))),,$$(word 2,$$(inkscape_info))))
	@$(call bml.print.testver,      inkscape,,,$(inkscape_ver), (EPS/PDF to SVG via Inkscape))
	@:
detect-mutool: announce-detect-image detect-pdftosvg-converter
	@$(eval mutool_info:=$$(if $$(MUTOOL),$$(shell $$(MUTOOL) -v 2>&1)))
	@$(eval mutool_ver:=$$(if $$(filter-out mutool,$$(firstword $$(mutool_info))),,$$(lastword $$(mutool_info))))
	@$(call bml.print.testver,        mutool,,,$(mutool_ver), (PDF to SVG via mutool))
	@:
detect-pdftocairo: announce-detect-image detect-pdftosvg-converter
	@$(eval pdftocairo_info:=$$(if $$(PDFTOCAIRO),$$(shell $$(PDFTOCAIRO) -v 2>&1)))
	@$(eval pdftocairo_ver:=$$(if $$(filter-out pdftocairo,$$(firstword $$(pdftocairo_info))),,$$(word 3,$$(pdftocairo_info))))
	@$(call bml.print.testver,    pdftocairo,,,$(pdftocairo_ver), (PDF to SVG via pdftocairo))
	@:

announce-detect-bmlimage: $(if $(filter detect detect-image,$(bml.utils.makecmdgoals)),detect-image)
	@$(call bml.print.redbox,     Optional: BookML images (\bmlImageEnvironment and \begin{bmlimage})      )
	@:
detect-bmlimage: announce-detect-bmlimage detect-preview
	@:
detect-preview: announce-detect-bmlimage
	@$(eval preview_loc:=$$(shell kpsewhich preview.sty 2>$$(bml.utils.null)))
	@$(eval preview_ver:=$$(if $$(preview_loc),$$(subst },,$$(subst _,., \
	  $$(subst RELEASE_,, $$(filter RELEASE_%,$$(subst \def\pr@version{,RELEASE_,$$(subst $$$$Name: release_,RELEASE_,$$(call bml.utils.read,$$(preview_loc))))))))))
	@$(call bml.print.testver,   preview.sty,11.81,,$(preview_ver))
	@:
# }))))))))))) syntax highlighting gets confused by the open curly bracket!

announce-detect-misc:
	@$(call bml.print.redbox,     Optional: misc                                                           )
	@:
detect-misc: detect-texfot detect-curl
	@:
detect-texfot: announce-detect-misc
	@$(call bml.print.testver,        texfot,,,$(wordlist 3,3,$(if $(TEXFOT),$(shell $(TEXFOT) --version 2>$(bml.utils.null)))), (hide irrelevant LaTeX messages))
	@:
detect-curl: announce-detect-misc
	@$(call bml.print.testver,          curl,,,$(wordlist 2,2,$(if $(CURL),$(shell $(CURL) -V 2>$(bml.utils.null)))), (update BookML with 'make update'))
	@:

endif # __bml.detect.mk.included