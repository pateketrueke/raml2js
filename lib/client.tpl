  // hack for embed raml-validation module
  var validate = (function() {
    var module = { exports: {} },
        exports = module.exports;

    <%= raml_validate.split('\n').join('\n    ') %>

    return module.exports();
  })();

  function ParameterError(message, errors, rules) {
    this.message = message;
    this.errors = errors;
    this.rules = rules;
    this.name = 'ParameterError';
  }

  ParameterError.prototype = Error.prototype;

  function validateObject(value, rules) {
    var result = validate(rules)(value);

    if (!result.valid) {
      throw new ParameterError('invalid arguments', result.errors, rules);
    }
  }

  function validateParameters(names, values, rules) {
    var obj = {};

    for (var key in names) {
      obj[names[key]] = values[key];
    }

    validateObject(obj, rules);
  }

  var defaults = <%= _.e(settings) %>;

  function merge() {
    var target = {};

    for (var index in arguments) {
      var source = arguments[index];

      for (var prop in source) {
        var value = source[prop];

        target[prop] = value !== 'undefined' && value !== null ? value : target[prop];
      }
    }

    return target;
  }

  function replace(value, container, current_key) {
    return value.replace(/\{(\w+)\}/g, function(match, prop) {
      if (current_key === prop) {
        throw new Error('cannot interpolate self-references for ' + match);
      }

      return container[prop];
    });
  }

  function <%= class_name %>(settings) {
    this._reset();
    this.options = merge(defaults, settings);
  }

  <%= class_name %>.prototype._reset = function() {
    this.resources = {};
    this._params = {};
    this._fetch = {};
  };

  <%= class_name %>.prototype.request = function(method, request_url, request_options) {
    switch (typeof request_url) {
      case 'object':
        request_options = request_url;
        request_url = request_options.path || '/';
        method = request_options.method || 'GET';
      break;

      default:
        if (typeof request_options === 'string') {
          method = request_options;
          request_options = {};
        } else {
          method = method || 'GET';
          request_options = request_options || {};
        }
      break;
    }

    delete request_options.path;
    delete request_options.method;

    if (typeof this._fetch !== 'function') {
      throw new Error('cannot invoke the request-handler');
    }

    return this._fetch(method, request_url, request_options);
  };

  <%= class_name %>.prototype.requestHandler = function(callback) {
    if (typeof callback !== 'function') {
      throw new Error('cannot use ' + callback + ' as request-handler');
    }

    this._fetch = callback;
  };

  var client = new <%= class_name %>(overrides);

  function setter(params, rules, resource) {
    return function() {
      var values = Array.prototype.slice.call(arguments);

      if (rules) {
        validateParameters(params, values, rules);
      }

      for (var key in params) {
        client._params[params[key]] = values[key];
      }

      return resource();
    };
  }

  function xhr(method, path, rules) {
    return function(params, options, async) {
      if (rules) {
        validateObject(params, rules);
      }

      var uri_params = merge(client._params, {
        version: client.options.version
      });

      return client.request(method, replace(client.options.baseUri + path, uri_params), { data: params || {} });
    };
  }

<% _.each(resources, function(resource) {
  if (resource.xhr) { %>  client.resources.<%= resource.property.join('.') %><%= 'delete' === resource.method ? '[' + _.e(resource.method) + ']' : '.' + resource.method %> = xhr(<%= _.e(resource.method.toUpperCase()) %>, <%= _.e(resource.path) %>, <%= _.e(resource.queryParameters || null) %>);

<% } else if (resource.keys) { %>  client.resources.<%= resource.property.join('.') %>.<%= resource.method %> = setter(<%= _.e(resource.keys) %>, <%= _.e(resource.uriParameters ? _.pick(resource.uriParameters, resource.keys) : null) %>, function() {
    return client.resources.<%= resource.property.join('.') %>.<%= resource.method %>;
  });

<% } else { %>  client.resources.<%= resource.property.join('.') %> = {};

<% } }); %>

  return client;
