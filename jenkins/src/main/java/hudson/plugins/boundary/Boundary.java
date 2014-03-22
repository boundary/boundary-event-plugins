/*
* Author:: Joe Williams (j@boundary.com)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
*/

/*
* some of this was based on https://github.com/jenkinsci/hudson-notifo-plugin
*/

package hudson.plugins.boundary;

import com.fasterxml.jackson.databind.ObjectMapper;
import hudson.model.AbstractBuild;
import hudson.model.BuildListener;
import hudson.model.Result;
import org.apache.commons.codec.binary.Base64;

import javax.net.ssl.HttpsURLConnection;
import java.io.Closeable;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.UnknownHostException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

public class Boundary
{
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private final String id;
    private final String token;

    public Boundary(String id, String token)
    {
        this.id = id;
        this.token = token;
    }

    private static void close(Closeable closeable) {
        if (closeable != null) {
            try {
                closeable.close();
            } catch (IOException e) {
                // Ignore
            }
        }
    }

    public void sendEvent(AbstractBuild<?, ?> build, BuildListener listener) throws IOException {
        final HashMap<String, Object> event = new HashMap<String, Object>();
        event.put("fingerprintFields", Arrays.asList("build name"));

        final Map<String, String> source = new HashMap<String, String>();
        String hostname = "localhost";

        try {
            hostname = java.net.InetAddress.getLocalHost().getHostName();
        }
        catch(UnknownHostException e) {
            listener.getLogger().println("host lookup exception: " + e);
        }

        source.put("ref", hostname);
        source.put("type", "jenkins");
        event.put("source", source);

        final Map<String, String> properties = new HashMap<String, String>();
        properties.put("build status", build.getResult().toString());
        properties.put("build number", build.getDisplayName());
        properties.put("build name", build.getProject().getName());
        event.put("properties", properties);

        event.put("title", String.format("Jenkins Build Job - %s - %s", build.getProject().getName(), build.getDisplayName()));

        if (Result.SUCCESS.equals(build.getResult())) {
            event.put("severity", "INFO");
            event.put("status", "CLOSED");
        }
        else {
            event.put("severity", "WARN");
            event.put("status", "OPEN");
        }

        final String url = String.format("https://api.boundary.com/%s/events", this.id);
        final HttpsURLConnection conn = (HttpsURLConnection) new URL(url).openConnection();
        conn.setConnectTimeout(30000);
        conn.setReadTimeout(30000);
        conn.setRequestMethod("POST");
        conn.setRequestProperty("Content-Type", "application/json");
        final String authHeader = "Basic " + new String(Base64.encodeBase64((token + ":").getBytes(), false));
        conn.setRequestProperty("Authorization", authHeader);
        conn.setDoInput(true);
        conn.setDoOutput(true);

        InputStream is = null;
        OutputStream os = null;
        try {
            os = conn.getOutputStream();
            OBJECT_MAPPER.writeValue(os, event);
            os.flush();
            is = conn.getInputStream();
        } finally {
            close(is);
            close(os);
        }

        final int responseCode = conn.getResponseCode();
        if (responseCode != HttpURLConnection.HTTP_CREATED) {
            listener.getLogger().println("Invalid HTTP response code from Boundary API: " + responseCode);
        }
        else {
            String location = conn.getHeaderField("Location");
            if (location.startsWith("http:")) {
                location = "https" + location.substring(4);
            }
            listener.getLogger().println("Created Boundary Event: " + location);
        }
    }
}
