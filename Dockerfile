FROM centos:6.4
ADD . /src
EXPOSE 80

# Install package dependencies
RUN yum install -y libjs libxslt libxml2 git curl httpd openssl raptor wget

# Install ruby
RUN wget -q ftp://ftp.ruby-lang.org//pub/ruby/1.9/ruby-1.9.2-p180.tar.gz
RUN tar zxvf ruby-1.9.2-p180.tar.gz
RUN cd ruby-1.9.2-p180/
RUN ./configure --prefix=/usr/local/ruby
RUN make
RUN make install

# Install passenger
RUN rpm --import http://passenger.stealthymonkeys.com/RPM-GPG-KEY-stealthymonkeys.asc
RUN yum install -y http://passenger.stealthymonkeys.com/rhel/6/passenger-release.noarch.rpm
RUN yum install -y mod_passenger

# Install gems
RUN gem install bundler
RUN cd /src; bundle install

# Set up virtual hosts
RUN cp /src/config/cn_proxy.conf /etc/httpd/conf.d/cn_proxy.conf

# Disable selinux and iptables
RUN echo 0 > /selinux/enforce
RUN /etc/init.d/iptables stop 

# Run!
CMD apachectl start