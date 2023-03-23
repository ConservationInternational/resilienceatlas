import Link from 'next/link';
import { Row, Column } from 'react-foundation';

import MainLayout from 'views/layouts/main';

import type { NextPageWithLayout } from './_app';

const AboutPage: NextPageWithLayout = () => {
  return (
    <div className="l-content">
      <div className="l-hero">
        <Row>
          <Column small={12} medium={8}>
            <h1 className="title">About</h1>
          </Column>
        </Row>
        <p className="credits">
          <a
            href="http://ci.tandemvault.com/lightboxes/JhUedHo8D?t=o9tS8BbuP#95371040"
            target="_blank"
            rel="noopener noreferrer"
          >
            © National Geographic Image Collection/Alamy Stock Photo
          </a>
        </p>
      </div>
      <nav className="l-section-nav">
        <Row>
          <Column small={12} medium={12}>
            <ul className="m-section-nav">
              <li>
                <a href="#overview" className="link">
                  overview
                </a>
              </li>
              <li>
                <a href="#using_the_atlas" className="link">
                  using RESILIENCE ATLAS
                </a>
              </li>
              <li>
                <a href="#team" className="link">
                  team
                </a>
              </li>
              <li>
                <a href="#sponsors" className="link">
                  sponsors
                </a>
              </li>
              <li>
                <a href="#data_policy" className="link">
                  data policy
                </a>
              </li>
              <li>
                <a href="#terminology">glossary</a>
              </li>
              {/* <li>
              <a href="#partnership" className="link">
                partnership
              </a>
            </li> */}
            </ul>
          </Column>
        </Row>
      </nav>
      <div className="wrap m-static-page">
        <article id="overview">
          <Row>
            <Column small={12} medium={6}>
              <h2>Overview</h2>
              <p>
                <span className="italic">Resilience</span> refers to the ability of a
                socio-ecological system to withstand, respond to, and adapt to stresses and shocks.
                While most of us have an intuitive understanding of resilience, the term also has
                technical meanings. Resilience often is conceptualized and approached differently by
                the development, disaster relief, and ecological communities. There is a growing
                body of scientific literature and community of practice focused on resilience, yet
                there are surprisingly few quantitative, integrative, multi-scale and data-driven
                analyses to inform resilience thinking and, particularly, the design of
                interventions and investments to promote resilience.
              </p>
              <p>
                In this context, we developed RESILIENCE ATLAS as an interactive analytical tool for
                building (1) understanding of the extent and severity of some of the key stressors
                and shocks that are affecting rural livelihoods, production systems, and ecosystems
                in the Sahel, Horn of Africa and South and Southeast Asia; and (2) insights into the
                ways that different types of wealth and assets (i.e., natural capital, human
                capital, social capital, financial capital and manufactured capital) – and
                combinations among these – impact resilience in particular contexts.
              </p>
              <p>
                The RESILIENCE ATLAS database was created by integrating and analyzing more than 12
                terabytes of data from over 60 of the best available datasets related to resilience,
                and summarizing the output in the form of easy to understand maps that can shift
                focus from regional to national and, where the availability and resolution of the
                data permit, to local scales. We hope the RESILIENCE ATLAS analytical tool and
                database provides new insights to help catalyze a revisioning of resilience and
                support for the growing community of practice around resilience.
              </p>
            </Column>

            <Column small={12} medium={6}>
              <figure>
                <img src="/images/about-1.jpg" alt="" />
                <figcaption className="credits">
                  <a
                    href="http://ci.tandemvault.com/lightboxes/JhUedHo8D?t=o9tS8BbuP#48967325"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    © Robb Kendrick/Aurora Photos
                  </a>
                </figcaption>
              </figure>
            </Column>
          </Row>
        </article>
        <article>
          <Row id="using_the_atlas">
            <Column small={12} medium={6}>
              <img src="/images/about-2.jpg" alt="" />
              <figcaption className="credits">
                <a
                  href="http://ci.tandemvault.com/lightboxes/JhUedHo8D?t=o9tS8BbuP#11891283"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  © Christopher Beauchamp/Aurora Photos
                </a>
              </figcaption>
            </Column>

            <Column small={12} medium={6}>
              <h2>Using RESILIENCE ATLAS</h2>
              <p>
                The RESILIENCE ATLAS analytical tool is structured to enable users to explore
                assessments of “the resilience of what to what”{' '}
                <a href="#McCarthy" className="link">
                  (Carpenter et al. 2001)
                </a>
                , i.e., resilience of particular socio-ecological systems in particular places to
                which stressors and shocks (e.g., resilience of pastoral systems in Ethiopia to
                decreasing rainfall and changes in rainfall distribution). We then consider how
                different types of wealth and assets promote or diminish the resilience of systems
                to specific stressors and shocks. To follow this framework, we suggest a 3-step
                approach to gain insights when using RESILIENCE ATLAS.
              </p>

              <ul>
                <li>
                  <p>
                    Decide what <span className="italic">geography</span> and theme are of interest:
                    within a particular geography, which livelihood, production system, or ecosystem
                    is of interest and what how is it distributed?
                  </p>
                </li>

                <li>
                  <p>
                    Examine
                    <span className="italic">exposure </span>
                    of the system of interest to
                    <span className="italic">stressors and shocks: </span> what are the different
                    types of stressors, how chronic are they and which acute shocks affect these
                    systems? What is the extent of exposure and the magnitude of the stress or
                    shock?
                  </p>
                </li>

                <li>
                  <p>
                    Consider
                    <span className="italic">vulnerability: </span>
                    how do different types of wealth and assets, i.e., natural capital, human
                    capital, social capital, financial capital and manufactured capital, increase or
                    decrease the resilience of the system to these stressors and shocks?
                  </p>
                </li>
              </ul>

              <p>
                The{' '}
                <Link href="/journeys">
                  <a>journeys</a>
                </Link>{' '}
                provide a curated pathway to explore some of the different data layers to gain new
                insights into the resilience of particular systems and places. The journeys
                demonstrate how to use the RESILIENCE ATLAS analytical tool and database to arrive
                at insights, and hopefully will stimulate you to explore the data further.
              </p>

              <p>
                Take a look through the data{' '}
                <Link href="/map">
                  <a>map</a>
                </Link>
                , don’t be overwhelmed, and start creating your own journeys and generating your own
                insights.
              </p>
            </Column>
          </Row>
        </article>
        <article>
          <Row id="team">
            <Column small={12} medium={12}>
              <h2>The team</h2>
              <section>
                <img src="/images/team/sandy_andelman.jpg" alt="" className="team-photo" />
                <div className="team-bio">
                  <h3>Sandy Andelman</h3>
                  <p>
                    Sandy Andelman is Chief Scientist and Senior Vice President at Conservation
                    International, providing science vision, strategy and thought leadership to
                    guide CI&apos;s work. She also is founding Executive Director of Vital Signs, a
                    monitoring system that fills a critical unmet need for integrative, diagnostic
                    data and indicators on agriculture, ecosystem services and human well-being.
                  </p>
                </div>
              </section>

              <section>
                <img className="team-photo" src="/images/team/sheila_brown.jpg" alt="" />
                <div className="team-bio">
                  <h3>Sheila Brown</h3>
                  <p>
                    Sheila Brown is GIS coordinator at Conservation International. Sheila holds a
                    Master of Environmental Management from the University of New South Wales and a
                    Graduate Certificate in Geographic Information Sciences from the University of
                    Southern California. Sheila assisted in the development of the journeys in
                    RESILIENCE ATLAS, and gathered and analyzed multiple datasets used in RESILIENCE
                    ATLAS.
                  </p>
                </div>
              </section>

              <section>
                <img className="team-photo" src="/images/team/kellee_koenig.jpg" alt="" />
                <div className="team-bio">
                  <h3>Kellee Koenig</h3>
                  <p>
                    Kellee Koenig is the GIS Manager and Cartographer at Conservation International.
                    Her role at CI focuses on the cartographic production of high-level map
                    products, GIS strategy and capacity building, cartographic training and support,
                    and spatial data management. Kellee has produced over 1,000 maps to date, which
                    are used for scientific publications, communications materials, presentations,
                    and proposals. Her work has been selected for inclusion in five Esri Map Books,
                    and she is a two-time winner of a Cartographic Special Interest Group award at
                    the Esri International Users Conference.
                  </p>
                </div>
              </section>

              <section>
                <img className="team-photo" src="/images/team/monica_noon.jpg" alt="" />
                <div className="team-bio">
                  <h3>Monica Noon</h3>
                  <p>
                    Monica Noon is Geographic Information Science (GIS) Manager at Conservation
                    International. Prior to joining Conservation International in 2016, Monica
                    worked with the National Audubon Society as an Enterprise GIS Intern, and served
                    as a Peace Corps Volunteer in the Linking Income, Food and the Environment
                    (LIFE) program in northern Zambia where she worked with rural communities to
                    build capacity in sustainable agriculture, forestry and food security. Monica
                    holds an MS in GIS for Development and Environment from Clark University where
                    she was awarded the Career Development Grant from the American Association of
                    University Women (AAUW), and a BS in Environmental Science from The Ohio State
                    University. She has an interest in protecting wildlife in Africa while fostering
                    local capacity to sustain healthy and prosperous livelihoods.
                  </p>
                </div>
              </section>

              <section>
                <img className="team-photo" src="/images/team/tim_noviello.jpg" alt="" />
                <div className="team-bio">
                  <h3>Tim Noviello</h3>
                  <p>
                    Tim Noviello is Director of Marketing and Communications for the Betty and
                    Gordon Moore Center for Science and Oceans at Conservation International. With
                    over ten years of experience in the field, Tim provides strategic guidance and
                    input on how to communicate science and structure decision support tools.
                  </p>
                </div>
              </section>

              <section>
                <img className="team-photo" src="/images/team/raghav_shyla.jpg" alt="" />
                <div className="team-bio">
                  <h3>Shyla Raghav</h3>
                  <p>
                    Shyla Raghav leads CI’s climate policy team to build and support the development
                    and implementation of sound regional, national and international science-based
                    climate change policies. Shyla and her interdisciplinary global team engage with
                    key partners to amplify CI&apos;s successful climate change strategies, which
                    demonstrate that ecosystem-based mitigation and adaptation offer tremendous
                    opportunities for meeting the climate challenge. Having attended nearly a decade
                    of United Nations climate change negotiations at the international level, she
                    works closely with governments to inform their positions and policies on finance
                    and climate change adaptation. Shyla holds a master’s in environmental
                    management from Yale University and a B.A. and B.S. from the University of
                    California, Irvine.
                  </p>
                </div>
              </section>

              <section>
                <img className="team-photo" src="/images/team/alex_zvoleff.jpg" alt="" />
                <div className="team-bio">
                  <h3>Alex Zvoleff</h3>
                  <p>
                    Alex Zvoleff is Director of Data Science for Vital Signs at Conservation
                    International. Alex leads the development of new methods and tools to integrate
                    large interdisciplinary datasets to enhance access to the best available
                    information on ecosystem management and human-wellbeing. With expertise in
                    statistical modeling and remote sensing, Alex has worked on a range of topics
                    exploring the interactions between climate, ecosystems, and human well-being.
                    Alex received a Ph.D. in geography in a joint program at San Diego State
                    University and the University of California, Santa Barbara, and holds a master’s
                    from Columbia University.
                  </p>
                </div>
              </section>

              <section>
                <img className="team-photo" src="/images/logo-vizzuality.svg" alt="" />
                <div className="team-bio">
                  <h3>Site design</h3>
                  <p>
                    <a
                      href="http://http://www.vizzuality.com/"
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      Vizzuality.com
                    </a>
                  </p>
                </div>
              </section>
            </Column>
          </Row>
        </article>
        <article id="sponsors">
          <Row>
            <Column small={12} medium={12}>
              <h2>Sponsors</h2>
              <section>
                <img
                  src="https://trackjs.com/assets/external/badge.gif"
                  alt="(Protected by TrackJS JavaScript Error Monitoring)"
                  className="team-photo"
                />
              </section>

              <section>
                <img
                  src="https://d26gfdfi90p7cf.cloudfront.net/rollbar-badge.144534.o.png"
                  alt="Error Tracking"
                  className="team-photo"
                />
                <div className="team-bio">
                  <h3>Rollbar</h3>
                  <p>
                    <a href="http://https://rollbar.com" target="_blank" rel="noopener noreferrer">
                      rollbar.com
                    </a>
                  </p>
                </div>
              </section>
            </Column>
          </Row>
        </article>
        <article id="data_policy">
          <Row>
            <Column small={12} medium={12}>
              <h2>Data policy</h2>
              <p>
                Unless indicated otherwise on this Website, the materials contained on this Website,
                including the RESILIENCE ATLAS trademark, are the property of CI, its licensors and
                collaborating organizations and are protected by U.S. and international copyright,
                trademark and other intellectual property laws.
              </p>
              <p>
                For Terms of Use, please see{' '}
                <a
                  href="http://www.conservation.org/Pages/terms.aspx"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  http://www.conservation.org/Pages/terms.aspx
                </a>
              </p>
              <p>
                Data sets owned/made available by the following organizations and individuals under
                separate terms as indicated in their respective metadata: Dartmouth Flood
                Observatory, Demographic and Health Surveys (DHS), Eastern Africa Grain Council,
                Ethiopian Agricultural Transformation Agency, European Space Agency, Famine Early
                Warning Systems Network (FEWS-NET), ICF International, Institute for Economics and
                Peace, International Union for Conservation of Nature (IUCN), MapSpaM, NASA Earth
                Exchange (NEX), Oak Ridge National Laboratory, United Nations Environment Programme,
                United Nations Food and Agriculture Organization (FAO), United States Agency for
                International Development (USAID), Université catholique de Louvain, William Cheung,
                World Bank, WorldPop, Yukiko Hirabayashi.
              </p>
              <p>
                Source information for each dataset in RESILIENCE ATLAS is available via the
                metadata link that accompanies each layer on the{' '}
                <Link href="/map">
                  <a>main map page</a>
                </Link>
                .
              </p>
              <p>
                CI acknowledges the contributions of the creators/owners of the following open
                source software components: CartoDB (BSD license), the Geospatial Data Abstraction
                Library (X11/​MIT License), and the R Statistical Computing Environment (GNU General
                Public License). CI acknowledges the contributions of the creators/owners of the
                following R packages: raster, rgdal, sp, gdalUtils, spatial.tools, foreach,
                doParallel, rgeos, ggplot2, reshape2, stringr, dplyr, RJSONIO, lme4, and rstan.
              </p>
            </Column>
          </Row>
        </article>

        <article id="terminology">
          <Row>
            <Column small={12} medium={12}>
              <h2>Glossary</h2>
              <p>
                <span className="italic">Resilience: </span>The ability to withstand, respond and
                adapt both in advance and in response to stresses and shocks
              </p>
              <p>
                <span className="italic">Exposure: </span>The extent of contact with a stressor or
                shock
              </p>
              <p>
                <span className="italic">Stressor: </span>A physical (e.g., climate), biological
                (e.g., a disease), social (e.g., conflict) or financial (e.g., market fluctuation)
                pressure or perturbation that causes a disturbance to a socio-ecological system.
                Stressors may affect the structure, function and/or controls in a system. They may
                be discrete or continuous, as well as cumulative.
              </p>
              <p>
                <span className="italic">Shock: </span>A sudden stressful event (e.g., a tsunami).
              </p>
              <p>
                <span className="italic">Vulnerability: </span>The degree to which a geophysical or
                socio-ecological system is susceptible to harm, has the capacity to adapt to or is
                unable to cope with the impacts of stressors and shocks (
                <a href="#McCarthy" className="link">
                  McCarthy et al.
                </a>{' '}
                <a href="#adger" className="link">
                  2001; Adger 2006
                </a>
                ).
              </p>
            </Column>
          </Row>
        </article>

        <article id="references">
          <Row>
            <Column small={12} medium={8}>
              <div className="references">
                <h3>References</h3>
                <p id="adger">
                  Adger, W. Neil. “Vulnerability.” Global Environmental Change 16, no. 3 (August
                  2006): 268–81.
                </p>
                <p id="McCarthy">
                  McCarthy, James J. Climate Change 2001: Impacts, Adaptation, and Vulnerability:
                  Contribution of Working Group II to the Third Assessment Report of the
                  Intergovernmental Panel on Climate Change. Cambridge University Press, 2001.
                </p>
                <p id="Carpenter">
                  Carpenter, Steve, Brian Walker, J. Marty Anderies, and Nick Abel. “From Metaphor
                  to Measurement: Resilience of What to What?” Ecosystems 4, no. 8 (2001): 765–81.
                </p>
              </div>
            </Column>
          </Row>
        </article>
      </div>
    </div>
  );
};

AboutPage.Layout = (page) => <MainLayout pageTitle="About">{page}</MainLayout>;

export default AboutPage;
