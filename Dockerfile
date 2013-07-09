FROM centos:6.4
ADD . /src
EXPOSE 80

# Bother to set a locale, mostly for ruby
RUN update-locale LANG=en_US.UTF-8

# Install build tools
RUN yum groupinstall -y 'Development Tools'

# Install package dependencies
RUN yum install -y js libxslt libxml2 httpd openssl raptor wget libev libev-devel zlib zlib-devel

# Install ruby
RUN cd /tmp; wget ftp://ftp.ruby-lang.org//pub/ruby/1.9/ruby-1.9.2-p180.tar.gz
RUN cd /tmp; tar zxvf ruby-1.9.2-p180.tar.gz
RUN cd /tmp/ruby-1.9.2-p180; ./configure
RUN cd /tmp/ruby-1.9.2-p180; make
RUN cd /tmp/ruby-1.9.2-p180; make install

# Install gems
RUN gem install bundler passenger
RUN cd /src; bundle install

# Install passenger
RUN passenger-install-apache2-module --auto
RUN passenger-install-apache2-module --snippet >> /etc/httpd/conf/httpd.conf

# Set up virtual hosts
RUN cp /src/config/cn_proxy.conf /etc/httpd/conf.d/cn_proxy.conf

# Disable selinux and iptables
RUN echo 0 > /selinux/enforce
RUN /etc/init.d/iptables stop 

# Run!
CMD service httpd restart