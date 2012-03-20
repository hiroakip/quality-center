require 'httparty'
require 'nokogiri'

module QualityCenter

  class RemoteInterface
    include HTTParty
    base_uri 'qualitycenter.ic.ncs.com:8080'
    AUTHURI  = {
      get:  '/qcbin/authentication-point/login.jsp',
      post: '/qcbin/authentication-point/j_spring_security_check'
    }
    PREFIX  = '/qcbin/rest'
    DEFECTS = '/domains/TEST/projects/AssessmentQualityGroup/defects'
    def initialize(u,p)
      @login = {:j_username => u, :j_password => p}
    end

    def login
      response = self.class.get AUTHURI[:get]
      response = self.class.post(
        AUTHURI[:post],
        body:    @login,
        headers: {'Cookie' => response.headers['Set-Cookie']}
      )
      raise "Login Error" if response.request.uri.to_s =~ /error/

      @cookie = response.request.options[:headers]['Cookie']
      response
    end

    def auth_get(url,prefix = PREFIX)
      login unless authenticated?
      self.class.get( prefix+url, headers: {'Cookie' => @cookie} )
    end

    def authenticated?
      return false unless @cookie
      return case self.class.get('/qcbin/rest/is-authenticated',
                                 headers: {'Cookie' => @cookie}).response.code
        when '200' then true
        else false
      end
    end

    # WIP
    def root
      ret = {}
      xml = auth_get('')
      parsed = Nokogiri::XML.parse(xml)
      parsed.css('ns2|workspace').each do |workspace|
        ret[workspace.css('title').first.text] = 
          Hash[
            workspace.css('ns2|collection').map{|x| [x.text,x.attributes['href'].value] }
          ]
      end
      ret
    end

    def recent_events
      "http://qualitycenter.ic.ncs.com:8080/qcbin/rest/domains/{domain}/projects/{project}/event-logs"
    end

  end

  class Data
    DATE_FIELDS = %w[closing-date creation-time last-modified]
    USER_FIELDS = %w[detected-by owner]

    # get the value of the Name attribute for a field
    def name(field)
      field.attributes['Name'].value
    end

    def nice_name(field)
      name = name(field)
      defect_fields[name] || name
    end

    def users
      return @users if @users
      usernames={}
      doc = Nokogiri::XML.parse(File.read '/home/brasca/git/qc_rest/users.xml')
      doc.css('User').each do |user|
        short = name(user)
        full  = user.attributes['FullName'].value
        usernames[ name(user).downcase ] = full.empty? ? short : full
      end
      usernames
    end

    def defect_fields
      return @defect_fields if @defect_fields
      fields={}
      doc = Nokogiri::XML.parse(File.read '/home/brasca/git/qc_rest/defect_fields.xml')
      doc.css('Field').each do |field|
        fields[ name(field) ] = field.attributes['Label'].value
      end
      fields
    end

    # get the value of the field, converting things like dates and user names
    def value(field)
      if DATE_FIELDS.include? (name=name(field))
        Time.parse(field.text) rescue field.text
      elsif USER_FIELDS.include? name
        users[field.text.downcase]
      else
        field.text
      end
    end

    # convert a single defect xml fragement into a hash
    def defect_to_hash(xml)
      defect={}
      xml.css('Field').each do |field|
        unless (text=field.text).empty?
          defect[ nice_name(field) ] = value(field)
        end
      end
      defect
    end

    def defects
      dxml = Nokogiri::XML.parse(File.read '/home/brasca/git/qc_rest/defects.xml')
      dxml.css('Entity').map{|defect| defect_to_hash(defect)}
    end


  end
end

